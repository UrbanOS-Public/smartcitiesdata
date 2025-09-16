defmodule Forklift.Jobs.DataMigrationTest do
  use ExUnit.Case
  use Mix.Config

  alias Forklift.Jobs.DataMigration
  alias SmartCity.TestDataGenerator, as: TDG
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Forklift.Jobs.JobUtils
  import Helper

  import Mox

  Mox.defmock(PrestigeHelperMock, for: Pipeline.Writer.TableWriter.Helper.PrestigeHelper)

  import SmartCity.Event,
    only: [
      dataset_update: 0,
      data_ingest_start: 0
    ]

  @instance_name Forklift.instance_name()

  setup do
    delete_all_datasets()

    dataset = TDG.create_dataset(%{technical: %{cadence: "once"}})
    Brook.Event.send(@instance_name, dataset_update(), :forklift, dataset)
    Brook.Event.send(@instance_name, data_ingest_start(), :forklift, dataset)

    wait_for_tables_to_be_created([dataset])

    on_exit(fn ->
      Application.put_env(:forklift, :overwrite_mode, false)
    end)

    [dataset: dataset, ingestion_id: Faker.UUID.v4(), extract_start: 123_456]
  end

  test "should insert partitioned data for only the specified extraction", %{
    dataset: dataset,
    ingestion_id: ingestion_id,
    extract_start: extract_start
  } do
    expected_records = 10
    other_ingestion_records = 2
    other_extraction_records = 3
    write_json_records(dataset, expected_records, ingestion_id, extract_start)
    write_json_records(dataset, other_ingestion_records, Faker.UUID.v4(), extract_start)
    write_json_records(dataset, other_extraction_records, ingestion_id, 789_101)

    result = DataMigration.compact(dataset, ingestion_id, extract_start)

    assert result == {:ok, dataset.id}

    assert count(dataset.technical.systemName) == expected_records

    table = dataset |> Map.get(:technical) |> Map.get(:systemName)
    {:ok, response} = PrestigeHelper.execute_query("select * from #{table}")

    actual_partition = response |> Prestige.Result.as_maps() |> List.first() |> Map.get("os_partition")

    assert {:ok, _} = Timex.parse(actual_partition, "{YYYY}_{0M}")

    assert count(dataset.technical.systemName <> "__json") == other_ingestion_records + other_extraction_records
  end

  test "Should refit tables before migration if they do not have an os_partition field", %{
    dataset: dataset,
    ingestion_id: ingestion_id,
    extract_start: extract_start
  } do
    {:ok, _} =
      "insert into #{dataset.technical.systemName} values (1, 'Bob', cast(now() as date), 1.5, true, 1662175490, '1234-abc-zyx')"
      |> PrestigeHelper.execute_query()

    expected_records = 10
    write_json_records(dataset, expected_records, ingestion_id, extract_start)

    DataMigration.compact(dataset, ingestion_id, extract_start)

    assert count(dataset.technical.systemName) == expected_records + 1

    {:ok, response} =
      PrestigeHelper.execute_query("select * from #{dataset.technical.systemName} order by os_partition asc")

    actual_partition = response |> Prestige.Result.as_maps() |> List.first() |> Map.get("os_partition")

    assert {:ok, _} = Timex.parse(actual_partition, "{YYYY}_{0M}")

    assert count(dataset.technical.systemName <> "__json") == 0
  end

  test "should error if the json data does not make it into the main table", %{
    dataset: dataset,
    ingestion_id: ingestion_id,
    extract_start: extract_start
  } do
    expected_records = 10
    write_json_records(dataset, expected_records, ingestion_id, extract_start)

    insert_query =
      "insert into #{dataset.technical.systemName} select *, date_format(now(), '%Y_%m') as os_partition from #{dataset.technical.systemName}__json where (_ingestion_id = '#{ingestion_id}' and _extraction_start_time = #{extract_start})"

    stub(PrestigeHelperMock, :execute_query, fn ^insert_query -> {:ok, :false_positive} end)

    result = DataMigration.compact(dataset, ingestion_id, extract_start)
    assert result == {:error, dataset.id}
  end

  test "should error if the json table's data is not deleted", %{
    dataset: dataset,
    ingestion_id: ingestion_id,
    extract_start: extract_start
  } do
    expected_records = 10
    write_json_records(dataset, expected_records, ingestion_id, extract_start)

    delete_query =
      "delete from #{dataset.technical.systemName}__json where (_ingestion_id = '#{ingestion_id}' and _extraction_start_time = #{extract_start})"

    stub(PrestigeHelperMock, :execute_query, fn ^delete_query -> {:ok, :false_positive} end)

    result = DataMigration.compact(dataset, ingestion_id, extract_start)
    assert result == {:error, dataset.id}
  end

  test "should error if the main table is missing", %{
    dataset: dataset,
    ingestion_id: ingestion_id,
    extract_start: extract_start
  } do
    "drop table #{dataset.technical.systemName}"
    |> PrestigeHelper.execute_query()

    result = DataMigration.compact(dataset, ingestion_id, extract_start)
    assert result == {:error, dataset.id}
  end

  test "should error if the json table is missing", %{
    dataset: dataset,
    ingestion_id: ingestion_id,
    extract_start: extract_start
  } do
    expected_records = 10
    write_json_records(dataset, expected_records, ingestion_id, extract_start)

    "drop table #{dataset.technical.systemName}__json"
    |> PrestigeHelper.execute_query()

    result = DataMigration.compact(dataset, ingestion_id, extract_start)
    assert result == {:error, dataset.id}
  end

  test "should abort `no data was found to migrate` per specified extraction", %{
    dataset: dataset,
    ingestion_id: ingestion_id,
    extract_start: extract_start
  } do
    :ok = write_json_records(dataset, 8, Faker.UUID.v4(), 456_771)
    result = DataMigration.compact(dataset, ingestion_id, extract_start)
    assert result == {:abort, dataset.id}
  end

  test "in overwrite mode, past extraction data should be deleted ", %{
    dataset: dataset,
    ingestion_id: ingestion_id
  } do
    main_table = dataset.technical.systemName
    json_table = dataset.technical.systemName <> "__json"
    past_data_extract_time = 000_001
    past_data_messages_count = 5
    new_data_extract_time = 000_005
    new_data_messages_count = 2
    other_extraction_messages = 11

    :ok = write_json_records(dataset, new_data_messages_count, ingestion_id, new_data_extract_time)

    {:ok, _past_data_messages_count} =
      populate_main_table(
        dataset,
        past_data_messages_count,
        ingestion_id,
        past_data_extract_time,
        "test setup failed to populate data in main table"
      )

    {:ok, _other_data_in_main_should_not_interfere} =
      populate_main_table(
        dataset,
        other_extraction_messages,
        Faker.UUID.v4(),
        123_456,
        "test setup failed to populate data in main table"
      )

    {:ok, _new_data_messages_count} =
      JobUtils.verify_extraction_count_in_table(
        json_table,
        ingestion_id,
        new_data_extract_time,
        new_data_messages_count,
        "test failed to simulate new data in json table"
      )

    # now there's old data in the main table, and new data in the json table
    # assert compaction in overwrite mode removes past extraction data from main
    Application.put_env(:forklift, :overwrite_mode, true)
    assert {:ok, _} = DataMigration.compact(dataset, ingestion_id, new_data_extract_time)

    assert {:ok, _} =
             JobUtils.verify_extraction_count_in_table(
               json_table,
               ingestion_id,
               new_data_extract_time,
               0,
               "compaction failed to remove data from json table"
             )

    assert {:ok, _} =
             JobUtils.verify_extraction_count_in_table(
               main_table,
               ingestion_id,
               new_data_extract_time,
               new_data_messages_count,
               "compaction failed to copy data from json table into main table"
             )

    assert count(main_table) == new_data_messages_count + other_extraction_messages
  end

  test "in overwrite mode, newer extraction data should not be deleted if present from already completed extractions",
       %{
         dataset: dataset,
         ingestion_id: ingestion_id
       } do
    main_table = dataset.technical.systemName
    json_table = dataset.technical.systemName <> "__json"
    past_data_extract_time = 000_001
    past_data_messages_count = 5
    new_data_extract_time = 000_005
    new_data_messages_count = 2
    other_extraction_messages = 11

    {:ok, new_data_messages_count} =
      populate_main_table(
        dataset,
        new_data_messages_count,
        ingestion_id,
        new_data_extract_time,
        "test failed to populate data in main table"
      )

    {:ok, _other_extraction_data_shouldnt_interfere} =
      populate_main_table(
        dataset,
        other_extraction_messages,
        Faker.UUID.v4(),
        123_456,
        "test failed to populate data in main table"
      )

    :ok = write_json_records(dataset, past_data_messages_count, ingestion_id, past_data_extract_time)

    {:ok, _} =
      JobUtils.verify_extraction_count_in_table(
        json_table,
        ingestion_id,
        past_data_extract_time,
        past_data_messages_count,
        "test failed to simulate data in json table"
      )

    # now there's new data in the main table, and stale data in the json table
    # this could happen if compactions are very very frequent, and one lags behind
    # assert that compaction has no effect, as we don't want to replace more
    #   recent data with old data
    Application.put_env(:forklift, :overwrite_mode, true)
    assert {:abort, _} = DataMigration.compact(dataset, ingestion_id, past_data_extract_time)

    assert {:ok, _} =
             JobUtils.verify_extraction_count_in_table(
               json_table,
               ingestion_id,
               past_data_extract_time,
               0,
               "compaction removed stale data from json table"
             )

    assert {:ok, _} =
             JobUtils.verify_extraction_count_in_table(
               main_table,
               ingestion_id,
               new_data_extract_time,
               new_data_messages_count,
               "compaction left more recent data unaffected"
             )

    assert count(main_table) == new_data_messages_count + other_extraction_messages
  end

  @spec populate_main_table(
          SmartCity.Dataset.t(),
          Integer.t(),
          String.t(),
          Integer.t(),
          String.t()
        ) :: {:ok, Integer.t()} | {:error, any()}
  defp populate_main_table(dataset, desired_count, ingestion_id, extract_time, err_msg) do
    write_json_records(dataset, desired_count, ingestion_id, extract_time)
    DataMigration.compact(dataset, ingestion_id, extract_time)

    JobUtils.verify_extraction_count_in_table(
      dataset.technical.systemName,
      ingestion_id,
      extract_time,
      desired_count,
      err_msg
    )
  end
end

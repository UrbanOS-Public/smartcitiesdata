defmodule Forklift.Jobs.DataMigrationTest do
  use ExUnit.Case

  alias Forklift.Jobs.DataMigration
  alias SmartCity.TestDataGenerator, as: TDG
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  import Helper

  use Placebo

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

    [dataset: dataset, ingestion_id: Faker.UUID.v4(), extract_start: 123_456]
  end

  test "should insert partitioned data for only the specified extraction", %{
    dataset: dataset,
    ingestion_id: ingestion_id,
    extract_start: extract_start
  } do
    expected_records = 10
    other_ingestion_records = 1
    other_extraction_records = 3
    write_records(dataset, expected_records, ingestion_id, extract_start)
    write_records(dataset, other_ingestion_records, Faker.UUID.v4(), extract_start)
    write_records(dataset, other_extraction_records, ingestion_id, 789_101)

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
    write_records(dataset, expected_records, ingestion_id, extract_start)

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
    write_records(dataset, expected_records, ingestion_id, extract_start)

    allow(
      PrestigeHelper.execute_query(
        "insert into #{dataset.technical.systemName} select *, date_format(now(), '%Y_%m') as os_partition from #{
          dataset.technical.systemName
        }__json"
      ),
      return: {:ok, :false_positive},
      meck_options: [:passthrough]
    )

    result = DataMigration.compact(dataset, ingestion_id, extract_start)
    assert result == {:error, dataset.id}
  end

  test "should error if the json table's data is not deleted", %{
    dataset: dataset,
    ingestion_id: ingestion_id,
    extract_start: extract_start
  } do
    expected_records = 10
    write_records(dataset, expected_records, ingestion_id, extract_start)

    allow(
      PrestigeHelper.execute_query("delete from #{dataset.technical.systemName}__json"),
      return: {:ok, :false_positive},
      meck_options: [:passthrough]
    )

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
    write_records(dataset, expected_records, ingestion_id, extract_start)

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
    :ok = write_records(dataset, 8, Faker.UUID.v4(), 456_771)
    result = DataMigration.compact(dataset, ingestion_id, extract_start)
    assert result == {:abort, dataset.id}
  end

  @tag :skip
  test "in overwrite mode, past extraction data should be deleted ", %{
    dataset: _dataset,
    ingestion_id: _ingestion_id,
    extract_start: _extract_start
  } do
    # todo:
    assert true == false
  end

  @tag :skip
  test "in overwrite mode, newer extraction data should not be deleted if present from completed extractions",
       %{
         dataset: _dataset,
         ingestion_id: _ingestion_id,
         extract_start: _extract_start
       } do
    # todo:
    assert true == false
  end
end

defmodule Forklift.Jobs.DataMigrationTest do
  use ExUnit.Case

  alias Forklift.Jobs.DataMigration
  alias SmartCity.TestDataGenerator, as: TDG
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  import SmartCity.TestHelper
  import Helper

  use Placebo

  import SmartCity.Event,
    only: [
      dataset_update: 0,
      data_ingest_start: 0
    ]

  @instance_name Forklift.instance_name()

  setup do
    Forklift.TestSupport.Datasets.delete_all()

    datasets =
      [1, 2]
      |> Enum.map(fn _ -> TDG.create_dataset(%{technical: %{cadence: "once"}}) end)
      |> Enum.map(fn dataset ->
        Brook.Event.send(@instance_name, dataset_update(), :forklift, dataset)
        Brook.Event.send(@instance_name, data_ingest_start(), :forklift, dataset)
        dataset
      end)

    wait_for_tables_to_be_created(datasets)
    delete_tables(datasets)
    recreate_tables_with_partitions(datasets)
    wait_for_tables_to_be_created(datasets)

    [datasets: datasets]
  end

  test "should insert partitioned data for each valid provided dataset id", %{datasets: datasets} do
    expected_records = 10
    Enum.each(datasets, fn dataset -> write_records(dataset, expected_records) end)

    results = DataMigration.run()

    assert results == [:ok, :ok]

    assert Enum.all?(datasets, fn dataset -> count(dataset.technical.systemName) == expected_records end)

    table = List.first(datasets) |> Map.get(:technical) |> Map.get(:systemName)
    {:ok, response} = PrestigeHelper.execute_query("select * from #{table}")
    actual_partition = response |> Prestige.Result.as_maps() |> List.first() |> Map.get("os_partition")
    assert {:ok, _} = Timex.parse(actual_partition, "{YYYY}_{0M}")

    assert Enum.all?(datasets, fn dataset -> count(dataset.technical.systemName <> "__json") == 0 end)
  end

  test "Should refit tables before migration if they do not have an os_partition field" do
    dataset = TDG.create_dataset(%{technical: %{cadence: "once"}})
    Brook.Event.send(@instance_name, dataset_update(), :forklift, dataset)
    Brook.Event.send(@instance_name, data_ingest_start(), :forklift, dataset)
    eventually(fn -> assert table_exists?(dataset.technical.systemName) end, 100, 1_000)
    eventually(fn -> assert table_exists?(dataset.technical.systemName <> "__json") end, 100, 1_000)

    "insert into #{dataset.technical.systemName} values (1, 'Bob', cast(now() as date), 1.5, true)"
    |> PrestigeHelper.execute_query()

    expected_records = 10
    write_records(dataset, expected_records)

    DataMigration.run()

    assert count(dataset.technical.systemName) == expected_records + 1

    {:ok, response} =
      PrestigeHelper.execute_query("select * from #{dataset.technical.systemName} order by os_partition asc")

    actual_partition = response |> Prestige.Result.as_maps() |> List.first() |> Map.get("os_partition")
    assert {:ok, _} = Timex.parse(actual_partition, "{YYYY}_{0M}")

    assert count(dataset.technical.systemName <> "__json") == 0
  end

  test "should error if the json data does not make it into the main table", %{datasets: datasets} do
    expected_records = 10
    Enum.each(datasets, fn dataset -> write_records(dataset, expected_records) end)

    error_dataset = List.first(datasets)

    allow(
      PrestigeHelper.execute_query(
        "insert into #{error_dataset.technical.systemName} select *, date_format(now(), '%Y_%m') as os_partition from #{
          error_dataset.technical.systemName
        }__json"
      ),
      return: {:ok, :false_positive},
      meck_options: [:passthrough]
    )

    assert [:error, :ok] == DataMigration.run()
  end

  test "should error if the json table's data is not deleted", %{datasets: datasets} do
    expected_records = 10
    Enum.each(datasets, fn dataset -> write_records(dataset, expected_records) end)

    error_dataset = List.first(datasets)

    allow(
      PrestigeHelper.execute_query("delete from #{error_dataset.technical.systemName}__json"),
      return: {:ok, :false_positive},
      meck_options: [:passthrough]
    )

    assert [:error, :ok] == DataMigration.run()
  end

  test "should error if the main table is missing", %{datasets: datasets} do
    expected_records = 10
    Enum.each(datasets, fn dataset -> write_records(dataset, expected_records) end)

    error_dataset = List.first(datasets)

    "drop table #{error_dataset.technical.systemName}"
    |> PrestigeHelper.execute_query()

    assert [:error, :ok] == DataMigration.run()
  end

  test "should error if the json table is missing", %{datasets: datasets} do
    expected_records = 10
    Enum.each(datasets, fn dataset -> write_records(dataset, expected_records) end)

    error_dataset = List.first(datasets)

    "drop table #{error_dataset.technical.systemName}__json"
    |> PrestigeHelper.execute_query()

    assert [:error, :ok] == DataMigration.run()
  end

  test "should abort no data was found to migrate", %{datasets: datasets} do
    assert [:abort, :abort] == DataMigration.run()
  end
end

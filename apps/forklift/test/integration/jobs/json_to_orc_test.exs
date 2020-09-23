defmodule Forklift.Jobs.JsonToOrcTest do
  use ExUnit.Case

  alias Forklift.Jobs.JsonToOrc
  alias SmartCity.TestDataGenerator, as: TDG
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  import SmartCity.TestHelper
  import Helper

  use Divo

  import SmartCity.Event,
    only: [
      dataset_update: 0,
      data_ingest_start: 0
    ]

  @instance Forklift.instance_name()

  setup do
    datasets =
      [1, 2]
      |> Enum.map(fn _ -> TDG.create_dataset(%{technical: %{cadence: "once"}}) end)
      |> Enum.map(fn dataset ->
        Brook.Event.send(@instance, dataset_update(), :forklift, dataset)
        Brook.Event.send(@instance, data_ingest_start(), :forklift, dataset)
        dataset
      end)

    # Wait for tables to be created
    eventually(
      fn ->
        assert Enum.all?(datasets, fn dataset -> table_exists?(dataset.technical.systemName) end)
      end,
      100,
      1_000
    )

    # Delete original tables
    Enum.each(datasets, fn dataset -> drop_table(dataset.technical.systemName) end)

    # Recreate orc tables from partitioned tables
    Enum.each(datasets, fn dataset -> create_partitioned_table(dataset.technical.systemName) end)

    # Wait for tables to be created
    eventually(
      fn ->
        assert Enum.all?(datasets, fn dataset -> table_exists?(dataset.technical.systemName) end)
      end,
      100,
      1_000
    )

    [datasets: datasets]
  end

  test "should insert partitioned data for each provided dataset id", %{datasets: datasets} do
    expected_records = 10
    Enum.each(datasets, fn dataset -> write_records(dataset, expected_records) end)

    # Run Job
    dataset_ids = Enum.map(datasets, fn dataset -> dataset.id end)
    JsonToOrc.run(dataset_ids)

    # Validate data is in orc table with os_partition
    assert Enum.all?(datasets, fn dataset -> count(dataset.technical.systemName) == expected_records end)

    table = List.first(datasets) |> Map.get(:technical) |> Map.get(:systemName)
    {:ok, response} = PrestigeHelper.execute_query("select * from #{table}")
    actual_partition = response |> Prestige.Result.as_maps() |> List.first() |> Map.get("os_partition")
    assert {:ok, _} = Timex.parse(actual_partition, "{YYYY}_{0M}")

    # Validate data is no longer in json table
    assert Enum.all?(datasets, fn dataset -> count(dataset.technical.systemName <> "__json") == 0 end)
  end

  # ensure ingestion is turned off while running
end

defmodule Forklift.Jobs.PartitionedCompactionTest do
  use ExUnit.Case
  alias SmartCity.TestDataGenerator, as: TDG
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Forklift.Jobs.PartitionedCompaction
  import SmartCity.TestHelper
  import Helper

  @instance Forklift.instance_name()

  use Divo

  import SmartCity.Event,
    only: [
      dataset_update: 0,
      data_ingest_start: 0
    ]

  setup do
    datasets =
      [1, 2]
      |> Enum.map(fn _ -> TDG.create_dataset(%{technical: %{cadence: "once"}}) end)
      |> Enum.map(fn dataset ->
        Brook.Event.send(@instance, dataset_update(), :forklift, dataset)
        Brook.Event.send(@instance, data_ingest_start(), :forklift, dataset)
        dataset
      end)

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

  test "partitioned compaction runs without loss or error", %{datasets: datasets} do
    partitions = [Timex.format!(DateTime.utc_now(), "{YYYY}_{0M}")]
    batch_count = 6
    expected_record_count = Enum.count(partitions) * batch_count

    datasets
    |> Enum.map(fn dataset ->
      Enum.each(partitions, fn partition ->
        write_partitioned_records(dataset, batch_count, partition)
      end)
    end)

    # given orc table with data (in multiple partitions?)
    dataset_ids = Enum.map(datasets, fn dataset -> dataset.id end)
    PartitionedCompaction.run(dataset_ids)

    # The expected number of records are present
    assert Enum.all?(datasets, fn dataset -> count(dataset.technical.systemName) == expected_record_count end)
    refute Enum.any?(datasets, fn dataset -> table_exists?(dataset.technical.systemName <> "__compact") end)

    # The expected # of partitioned files are present
    assert Enum.all?(datasets, fn dataset -> count_files(dataset.technical.systemName) == Enum.count(partitions) end)

    # No errors have occurred
  end

  defp count_files(table) do
    [[count]] =
      "select count(distinct \"$path\") from #{table}" |> PrestigeHelper.execute_query() |> elem(1) |> Map.get(:rows)

    count
  end
end

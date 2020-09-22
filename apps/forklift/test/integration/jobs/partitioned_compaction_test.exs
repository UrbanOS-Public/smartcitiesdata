defmodule Forklift.Jobs.PartitionedCompactionTest do
  use ExUnit.Case
  alias SmartCity.TestDataGenerator, as: TDG
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias Forklift.Jobs.PartitionedCompaction
  import SmartCity.TestHelper
  import Helper
  use Placebo

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

    expected_record_count = write_test_data(datasets, partitions, batch_count)

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

  test "abort compaction without loss if the compacted table for the partition exists at the start", %{datasets: datasets} do
    partitions = ["2018_01", Timex.format!(DateTime.utc_now(), "{YYYY}_{0M}")]
    expected_record_count = write_test_data(datasets, partitions, 6)

    error_dataset = List.first(datasets)

    "create table #{error_dataset.technical.systemName}__compact as select 1 as number_col"
    |> PrestigeHelper.execute_query()

    dataset_ids = Enum.map(datasets, fn dataset -> dataset.id end)
    compaction_results = PartitionedCompaction.run(dataset_ids)

    assert compaction_results == [:abort, :ok]
    assert table_exists?(error_dataset.technical.systemName <> "__compact")
    assert Enum.all?(datasets, fn dataset -> count(dataset.technical.systemName) == expected_record_count end)
  end

  test "abort compaction if the main table does not exist", %{datasets: datasets} do
    partitions = ["2018_01", Timex.format!(DateTime.utc_now(), "{YYYY}_{0M}")]
    write_test_data(datasets, partitions, 6)

    error_dataset = List.first(datasets)

    "drop table #{error_dataset.technical.systemName}"
    |> PrestigeHelper.execute_query()

    dataset_ids = Enum.map(datasets, fn dataset -> dataset.id end)
    compaction_results = PartitionedCompaction.run(dataset_ids)

    assert compaction_results == [:abort, :ok]
    refute table_exists?(error_dataset.technical.systemName <> "__compact")
  end

  test "fail compaction without loss if the compacted table does not have the appropriate count", %{datasets: datasets} do
    error_dataset = List.first(datasets)

    allow(PrestigeHelper.count("#{error_dataset.technical.systemName}__compact"),
      return: 0,
      meck_options: [:passthrough]
    )

    partitions = ["2018_01", Timex.format!(DateTime.utc_now(), "{YYYY}_{0M}")]
    expected_record_count = write_test_data(datasets, partitions, 6)

    dataset_ids = Enum.map(datasets, fn dataset -> dataset.id end)
    compaction_results = PartitionedCompaction.run(dataset_ids)

    assert compaction_results == [:error, :ok]
    assert Enum.all?(datasets, fn dataset -> count(dataset.technical.systemName) == expected_record_count end)
  end

  test "fail compaction, preserving the compacted table, if the final table does not have the appropriate count", %{datasets: datasets} do
    partitions = ["2018_01", Timex.format!(DateTime.utc_now(), "{YYYY}_{0M}")]
    batch_size = 6

    expected_record_count = write_test_data(datasets, partitions, batch_size)

    error_dataset = List.first(datasets)

    allow(
      PrestigeHelper.execute_query(
        "insert into #{error_dataset.technical.systemName} select * from #{error_dataset.technical.systemName}__compact"
      ),
      return: {:ok, :false_positive},
      meck_options: [:passthrough]
    )

    dataset_ids = Enum.map(datasets, fn dataset -> dataset.id end)
    compaction_results = PartitionedCompaction.run(dataset_ids)

    assert compaction_results == [:error, :ok]

    assert count_test(error_dataset.technical.systemName) == batch_size
    assert table_exists?(error_dataset.technical.systemName <> "__compact")
    assert count_test(error_dataset.technical.systemName <> "__compact") == batch_size
  end

  defp write_test_data(datasets, partitions, batch_count) do
    datasets
    |> Enum.map(fn dataset ->
      Enum.each(partitions, fn partition ->
        write_partitioned_records(dataset, batch_count, partition)
      end)
    end)

    Enum.count(partitions) * batch_count
  end

  defp count_test(table) do
    PrestigeHelper.count_query("select count(1) from #{table} /* test */")
  end

  defp count_files(table) do
    [[count]] =
      "select count(distinct \"$path\") from #{table}" |> PrestigeHelper.execute_query() |> elem(1) |> Map.get(:rows)

    count
  end
end

defmodule DatasetCompactorTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.Datasets.DatasetCompactor
  alias SmartCity.TestDataGenerator, as: TDG

  @moduletag capture_log: true

  describe "compact_dataset/1" do
    setup do
      allow(Forklift.Datasets.DatasetHandler.handle_dataset(any()), return: {:ok, :pid})
      :ok
    end

    setup do
      dataset = TDG.create_dataset(%{id: "1", technical: %{systemName: "big_data"}})
      allow(Prestige.prefetch(:count), return: [[2]])
      allow(Prestige.prefetch(any()), return: :ok)
      allow(Prestige.execute("select count(1) from big_data", any()), return: :count)
      allow(Prestige.execute("select count(1) from big_data_compact", any()), return: :count)

      [
        dataset: dataset
      ]
    end

    test "creates a new table from the old one", %{dataset: dataset} do
      expected_statement = "create table big_data_compact as (select * from big_data)"
      expect(Prestige.execute(expected_statement, any()), return: :ok)
      allow(Prestige.execute(any(), any()), return: :ok)

      DatasetCompactor.compact_dataset(dataset)

      assert_called(Prestige.execute(expected_statement, any()), once())
    end

    test "renames compact table to systemName", %{dataset: dataset} do
      expected_statement = "alter table big_data_compact rename to big_data"

      expect(Prestige.execute(expected_statement, any()), return: [[true]])
      allow(Prestige.execute(any(), any()), return: :ok)

      DatasetCompactor.compact_dataset(dataset)

      assert_called(Prestige.execute(expected_statement, any()), once())
    end

    test "cleans up previous _compact tables if they exist" do
      datasets = [
        TDG.create_dataset(%{id: "2", technical: %{systemName: "ingest", sourceType: "ingest"}})
      ]

      allow(SmartCity.Dataset.get_all!(), return: datasets, meck_options: [:passthrough])
      allow(Prestige.execute(any(), any()), return: :ok)
      allow(Prestige.prefetch(any()), return: :ok)

      DatasetCompactor.compact_datasets()

      assert_called(
        Prestige.execute("drop table if exists ingest_compact", any()),
        once()
      )
    end

    test "deletes original table" do
      datasets = [
        TDG.create_dataset(%{id: "3", technical: %{systemName: "ingest", sourceType: "ingest"}})
      ]

      allow(SmartCity.Dataset.get_all!(), return: datasets, meck_options: [:passthrough])
      allow(Prestige.execute("select count(1) from ingest", any()), return: :count)
      allow(Prestige.execute("select count(1) from ingest_compact", any()), return: :count)
      allow(Prestige.execute(any(), any()), return: :ok)
      allow(Prestige.prefetch(any()), return: :ok)

      DatasetCompactor.compact_datasets()

      assert_called(
        Prestige.execute("drop table ingest", any()),
        once()
      )
    end

    test "returns ok if no ingest process to pause", %{dataset: _dataset} do
      assert(DatasetCompactor.pause_ingest(:no_process) == :ok)
    end

    test "records metrics for time to compact datasets", %{dataset: dataset} do
      allow(Prestige.execute(any(), any()), return: :ok)

      expect(
        StreamingMetrics.PrometheusMetricCollector.count_metric(
          any(),
          "dataset_compaction_duration_total",
          [{"system_name", "#{dataset.technical.systemName}"}]
        ),
        meck_options: [:passthrough]
      )

      DatasetCompactor.compact_dataset(dataset)
    end
  end

  describe "compact_dataset/1 error cases" do
    setup do
      allow(Forklift.Datasets.DatasetHandler.handle_dataset(any()), return: {:ok, :pid})
      :ok
    end

    setup do
      dataset = TDG.create_dataset(%{id: "1", technical: %{systemName: "big_bad_data"}})

      [
        dataset: dataset
      ]
    end

    test "returns :error if compact fails for any reason", %{dataset: dataset} do
      allow(Prestige.execute(any(), any()), return: :ok)
      allow(Prestige.prefetch(any()), exec: fn _ -> raise :error end)

      assert(DatasetCompactor.compact_dataset(dataset) == :error)
    end

    test "does not delete original table if counts do not match" do
      datasets = [
        TDG.create_dataset(%{id: "3", technical: %{systemName: "ingest", sourceType: "ingest"}})
      ]

      allow(SmartCity.Dataset.get_all!(), return: datasets, meck_options: [:passthrough])
      allow(Prestige.execute("select count(1) from ingest_compact", any()), return: :bad_count)
      allow(Prestige.execute("select count(1) from ingest", any()), return: :count)
      allow(Prestige.execute(any(), any()), return: :ok)
      allow(Prestige.prefetch(:bad_count), return: [[1]])
      allow(Prestige.prefetch(:count), return: [[2]])
      allow(Prestige.prefetch(any()), return: :ok)

      DatasetCompactor.compact_datasets()

      assert_called(
        Prestige.execute("drop table ingest", any()),
        times(0)
      )
    end
  end

  describe "compact_datasets/0" do
    setup do
      allow(Forklift.Datasets.DatasetHandler.handle_dataset(any()), return: {:ok, :pid})
      :ok
    end

    test "only processes ingest and stream type datasets" do
      datasets = [
        TDG.create_dataset(%{id: "1", technical: %{systemName: "remote", sourceType: "remote"}}),
        TDG.create_dataset(%{id: "2", technical: %{systemName: "ingest", sourceType: "ingest"}}),
        TDG.create_dataset(%{id: "3", technical: %{systemName: "host", sourceType: "host"}}),
        TDG.create_dataset(%{id: "4", technical: %{systemName: "stream", sourceType: "stream"}})
      ]

      allow(SmartCity.Dataset.get_all!(), return: datasets, meck_options: [:passthrough])
      allow(Prestige.execute(any(), any()), return: :ok)
      allow(Prestige.prefetch(any()), return: :ok)

      DatasetCompactor.compact_datasets()

      assert_called(
        Prestige.execute("create table ingest_compact as (select * from ingest)", any()),
        once()
      )

      assert_called(
        Prestige.execute("create table stream_compact as (select * from stream)", any()),
        once()
      )

      refute_called(Prestige.execute("create table remote_compact as (select * from remote)", any()))

      refute_called(Prestige.execute("create table host_compact as (select * from host)", any()))
    end

    test "does not bomb out if one of the datasets fails to compact" do
      datasets = [
        TDG.create_dataset(%{id: "2", technical: %{systemName: "ingest", sourceType: "ingest"}})
      ]

      allow(SmartCity.Dataset.get_all!(), return: datasets, meck_options: [:passthrough])
      allow(Prestige.execute(any(), any()), return: :ok)
      allow(Prestige.prefetch(any()), return: :ok)

      allow(Forklift.Datasets.DatasetHandler.handle_dataset(any()),
        return: {:error},
        meck_options: [:passthrough]
      )

      assert(DatasetCompactor.compact_datasets() == :ok)
    end
  end
end

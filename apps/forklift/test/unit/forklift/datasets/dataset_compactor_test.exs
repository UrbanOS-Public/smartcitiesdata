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
      allow(Prestige.prefetch(any()), return: :ok)

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

    test "renames old table to systemName_archive", %{dataset: dataset} do
      expected_statement = "alter table big_data rename to big_data_archive"

      expect(Prestige.execute(expected_statement, any()), return: :ok)
      allow(Prestige.execute(any(), any()), return: :ok)

      DatasetCompactor.compact_dataset(dataset)

      assert_called(Prestige.execute(expected_statement, any()), once())
    end

    test "renames compact table to systemName", %{dataset: dataset} do
      expected_statement = "alter table big_data_compact rename to big_data"

      expect(Prestige.execute(expected_statement, any()), return: :ok)
      allow(Prestige.execute(any(), any()), return: :ok)

      DatasetCompactor.compact_dataset(dataset)

      assert_called(Prestige.execute(expected_statement, any()), once())
    end

    test "drops old archive table if it exists", %{dataset: dataset} do
      expected_statement = "drop table if exists big_data_archive"

      expect(Prestige.execute(expected_statement, any()), return: :ok)
      allow(Prestige.execute(any(), any()), return: :ok)

      DatasetCompactor.compact_dataset(dataset)

      assert_called(Prestige.execute(expected_statement, any()), once())
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

    test "puts archive table back if compact table is in a bad state", %{dataset: dataset} do
      allow(
        Prestige.execute(
          "alter table #{dataset.technical.systemName}_compact
            rename to #{dataset.technical.systemName}" |> String.split() |> Enum.join(" "),
          any()
        ),
        return: :bad_table
      )

      allow(Prestige.execute(any(), any()), return: :ok)

      allow(Prestige.prefetch(:bad_table), exec: fn _ -> raise :error end)
      allow(Prestige.prefetch(any()), return: :ok)

      assert(DatasetCompactor.compact_dataset(dataset) == :error)

      assert_called(
        Prestige.execute(
          "alter table #{dataset.technical.systemName}_archive
            rename to #{dataset.technical.systemName}" |> String.split() |> Enum.join(" "),
          any()
        ),
        once()
      )
    end
  end

  describe "compact_datasets/0" do
    setup do
      allow(Forklift.Datasets.DatasetHandler.handle_dataset(any()), return: {:ok, :pid})
      :ok
    end

    test "only processes ingest type datasets" do
      datasets = [
        TDG.create_dataset(%{id: "1", technical: %{systemName: "remote", sourceType: "remote"}}),
        TDG.create_dataset(%{id: "2", technical: %{systemName: "ingest", sourceType: "ingest"}}),
        TDG.create_dataset(%{id: "3", technical: %{systemName: "host", sourceType: "host"}})
      ]

      allow(SmartCity.Dataset.get_all!(), return: datasets, meck_options: [:passthrough])
      allow(Prestige.execute(any(), any()), return: :ok)
      allow(Prestige.prefetch(any()), return: :ok)

      DatasetCompactor.compact_datasets()

      assert_called(
        Prestige.execute("create table ingest_compact as (select * from ingest)", any()),
        once()
      )

      refute_called(Prestige.execute("create table remote_compact as (select * from remote)", any()))

      refute_called(Prestige.execute("create table host_compact as (select * from host)", any()))
    end
  end
end

defmodule DatasetCompactorTest do
  use ExUnit.Case
  use Placebo
  alias Forklift.Datasets.{DatasetHandler, DatasetCompactor, DatasetSchema}
  alias SmartCity.TestDataGenerator, as: TDG

  @moduletag capture_log: true

  describe "compact_dataset/1" do
    setup do
      dataset = TDG.create_dataset(%{id: "1", technical: %{systemName: "big_data"}})
      schema = DatasetSchema.from_dataset(dataset)

      allow DatasetHandler.start_dataset_ingest(any()), return: {:ok, :pid}
      allow DatasetHandler.stop_dataset_ingest(any()), return: :ok

      allow(Prestige.prefetch(:count), return: [[2]])
      allow(Prestige.prefetch(any()), return: :ok)
      allow(Prestige.execute("select count(1) from big_data", any()), return: :count)
      allow(Prestige.execute("select count(1) from big_data_compact", any()), return: :count)

      [
        dataset: dataset,
        schema: schema
      ]
    end

    test "creates a new table from the old one", %{schema: schema} do
      expected_statement = "create table #{schema.system_name}_compact as (select * from #{schema.system_name})"
      expect(Prestige.execute(expected_statement, any()), return: :ok)
      allow(Prestige.execute(any(), any()), return: :ok)

      DatasetCompactor.compact_dataset(schema)

      assert_called(Prestige.execute(expected_statement, any()), once())
    end

    test "renames compact table to systemName", %{schema: schema} do
      expected_statement = "alter table #{schema.system_name}_compact rename to #{schema.system_name}"

      expect(Prestige.execute(expected_statement, any()), return: [[true]])
      allow(Prestige.execute(any(), any()), return: :ok)

      DatasetCompactor.compact_dataset(schema)

      assert_called(Prestige.execute(expected_statement, any()), once())
    end

    test "records metrics for time to compact datasets", %{schema: schema} do
      allow(Prestige.execute(any(), any()), return: :ok)

      expect(
        StreamingMetrics.PrometheusMetricCollector.count_metric(
          any(),
          "dataset_compaction_duration_total",
          [{"system_name", "#{schema.system_name}"}]
        ),
        meck_options: [:passthrough]
      )

      DatasetCompactor.compact_dataset(schema)
    end
  end

  describe("compact_datasets/0") do
    setup do
      schemas = [
        %DatasetSchema{id: "3", system_name: "org__stuff", columns: []},
        %DatasetSchema{id: "4", system_name: "org__things", columns: []}
      ]

      allow(Brook.get_all_values!(:forklift, :datasets_to_process), return: schemas, meck_options: [:passthrough])
      allow(Prestige.execute("select count(1) from org__stuff", any()), return: :count)
      allow(Prestige.execute("select count(1) from org__stuff_compact", any()), return: :count)
      allow(Prestige.execute("select count(1) from org__things", any()), return: :count)
      allow(Prestige.execute("select count(1) from org__things_compact", any()), return: :count)
      allow(Prestige.execute(any(), any()), return: :ok)
      allow(Prestige.prefetch(:count), return: [[2]])
      allow(Prestige.prefetch(any()), return: :ok)
      allow DatasetHandler.start_dataset_ingest(any()), return: {:ok, :pid}
      allow DatasetHandler.stop_dataset_ingest(any()), return: :ok

      :ok
    end

    test "deletes original table" do
      DatasetCompactor.compact_datasets()

      assert_called(
        Prestige.execute("drop table org__stuff", any()),
        once()
      )

      assert_called(
        Prestige.execute("drop table org__things", any()),
        once()
      )
    end

    test "cleans up previous _compact tables if they exist" do
      DatasetCompactor.compact_datasets()

      assert_called(
        Prestige.execute("drop table if exists org__stuff_compact", any()),
        once()
      )

      assert_called(
        Prestige.execute("drop table if exists org__things_compact", any()),
        once()
      )
    end
  end

  describe "compact_dataset/1 error cases" do
    setup do
      dataset = TDG.create_dataset(%{id: "1", technical: %{systemName: "big_bad_data"}})
      schema = DatasetSchema.from_dataset(dataset)

      allow DatasetHandler.start_dataset_ingest(schema), return: {:ok, :pid}
      allow DatasetHandler.stop_dataset_ingest(schema), return: :ok

      [
        dataset: dataset,
        schema: schema
      ]
    end

    test "returns :error if compact fails for any  reason", %{schema: schema} do
      allow(Prestige.execute(any(), any()), return: :ok)
      allow(Prestige.prefetch(any()), exec: fn _ -> raise :error end)

      assert DatasetCompactor.compact_dataset(schema) == :error
    end
  end

  describe "compact_datasets/0 errors" do
    test "does not bomb out if one of the datasets fails to compact" do
      schemas = [
        %DatasetSchema{id: "3", system_name: "org__stuff", columns: []},
        %DatasetSchema{id: "4", system_name: "org__things", columns: []}
      ]

      allow(Brook.get_all_values!(:forklift, :datasets_to_process), return: schemas, meck_options: [:passthrough])
      allow(Prestige.execute(any(), any()), return: :ok)
      allow(Prestige.prefetch(any()), return: :ok)
      allow DatasetHandler.start_dataset_ingest(any()), return: {:ok, :pid}
      allow DatasetHandler.stop_dataset_ingest(any()), return: :ok

      allow(Forklift.Datasets.DatasetHandler.start_dataset_ingest(%{id: "3"}),
        exec: fn _ -> raise RuntimeError, "failed real bad" end
      )

      allow(Forklift.Datasets.DatasetHandler.start_dataset_ingest(%{id: "4"}), return: {:ok, :pid})

      assert(DatasetCompactor.compact_datasets() == :ok)
    end

    test "does not delete original table if counts do not match" do
      schemas = [
        %DatasetSchema{id: "3", system_name: "org__stuff", columns: []}
      ]

      allow(Brook.get_all_values!(:forklift, :datasets_to_process), return: schemas, meck_options: [:passthrough])
      allow(Prestige.execute("select count(1) from org__stuff", any()), return: :bad_count)
      allow(Prestige.execute("select count(1) from org__stuff_compact", any()), return: :count)
      allow(Prestige.execute(any(), any()), return: :ok)
      allow(Prestige.prefetch(:bad_count), return: [[1]])
      allow(Prestige.prefetch(:count), return: [[2]])
      allow(Prestige.prefetch(any()), return: :ok)
      allow DatasetHandler.start_dataset_ingest(any()), return: {:ok, :pid}
      allow DatasetHandler.stop_dataset_ingest(any()), return: :ok

      DatasetCompactor.compact_datasets()

      refute_called(Prestige.execute("drop table org__stuff", any()))
    end
  end
end

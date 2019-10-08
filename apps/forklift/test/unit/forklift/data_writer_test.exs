defmodule Forklift.DataWriterTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.DataWriter
  alias SmartCity.TestDataGenerator, as: TDG
  import Mox

  setup :set_mox_global
  setup :verify_on_exit!

  describe "compact_datasets/0" do
    test "compacts other tables if one fails" do
      test = self()

      datasets = [
        TDG.create_dataset(%{technical: %{systemName: "fail"}}),
        TDG.create_dataset(%{technical: %{systemName: "one"}}),
        TDG.create_dataset(%{technical: %{systemName: "two"}})
      ]

      allow Forklift.Datasets.get_all!(), return: datasets
      allow DataWriter.Metric.record(any(), any()), return: :ok
      stub(MockReader, :terminate, fn _ -> :ok end)
      stub(MockReader, :init, fn _ -> :ok end)

      expect(MockTable, :compact, 3, fn args ->
        case args[:table] do
          "fail" ->
            {:error, "reason"}

          table ->
            send(test, table)
            :ok
        end
      end)

      assert :ok = DataWriter.compact_datasets()
      assert_receive "one"
      assert_receive "two"
      refute_receive "fail"
    end

    test "records duration" do
      stub(MockTable, :compact, fn _ -> :ok end)
      stub(MockReader, :terminate, fn _ -> :ok end)
      stub(MockReader, :init, fn _ -> :ok end)

      MockMetricCollector
      |> expect(:count_metric, 2, fn dur, "dataset_compaction_duration_total", _, _ when is_integer(dur) -> [100] end)

      expect(MockMetricCollector, :record_metrics, 2, fn [100], "forklift" -> {:ok, :ok} end)

      datasets = [TDG.create_dataset(%{}), TDG.create_dataset(%{})]
      allow Forklift.Datasets.get_all!(), return: datasets

      assert :ok = DataWriter.compact_datasets()
    end

    test "stops/restarts ingestion around each compaction" do
      stub(MockMetricCollector, :count_metric, fn _, _, _, _ -> [42] end)
      stub(MockMetricCollector, :record_metrics, fn [42], "forklift" -> {:ok, :ok} end)
      stub(MockTable, :compact, fn _ -> :ok end)

      expect(MockReader, :terminate, 4, fn _ -> :ok end)
      expect(MockReader, :init, 4, fn _ -> :ok end)

      dataset = TDG.create_dataset(%{})
      allow Forklift.Datasets.get_all!(), return: [dataset, dataset, dataset, dataset]

      assert :ok = DataWriter.compact_datasets()
    end
  end
end

defmodule Forklift.Integration.EventHandlingTest do
  use ExUnit.Case
  use Placebo

  import Mox
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0, data_ingest_end: 0]

  alias SmartCity.TestDataGenerator, as: TDG

  setup :set_mox_global
  setup :verify_on_exit!

  describe "on dataset:update event" do
    test "ensures table exists for a dataset" do
      test = self()
      expect(Forklift.MockTable, :init, fn args -> send(test, args) end)

      dataset = TDG.create_dataset(%{})
      table_name = dataset.technical.systemName
      schema = dataset.technical.schema

      Brook.Event.send(:forklift, dataset_update(), :author, dataset)
      assert_receive name: ^table_name, schema: ^schema
    end
  end

  describe "on data:ingest:start event" do
    test "ensures dataset topic exists" do
      test = self()

      Forklift.MockReader
      |> expect(:init, fn args ->
        send(test, Keyword.get(args, :dataset))
        :ok
      end)

      dataset = TDG.create_dataset(%{id: "dataset-id"})
      Brook.Event.send(:forklift, data_ingest_start(), :author, dataset)

      assert_receive %SmartCity.Dataset{id: "dataset-id"}
    end
  end

  describe "on data:ingest:end event" do
    test "tears reader infrastructure down" do
      test = self()

      expect(Forklift.MockReader, :terminate, fn args ->
        send(test, args[:dataset])
        :ok
      end)

      expect Forklift.Datasets.delete("terminate-id"), return: :ok

      dataset = TDG.create_dataset(%{id: "terminate-id"})
      Brook.Event.send(:forklift, data_ingest_end(), :author, dataset)

      assert_receive %SmartCity.Dataset{id: "terminate-id"}
    end
  end
end

defmodule Forklift.Integration.DatasetUpdateTest do
  use ExUnit.Case

  import Mox
  import SmartCity.Event, only: [dataset_update: 0]

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
end

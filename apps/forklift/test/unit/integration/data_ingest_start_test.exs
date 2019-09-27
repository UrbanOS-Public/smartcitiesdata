defmodule Forklift.Integration.DataIngestStartTest do
  use ExUnit.Case

  import Mox
  import SmartCity.Event, only: [data_ingest_start: 0]

  alias SmartCity.TestDataGenerator, as: TDG

  setup :set_mox_global
  setup :verify_on_exit!

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
end

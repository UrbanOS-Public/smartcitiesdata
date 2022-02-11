defmodule Alchemist.InitTest do
  use ExUnit.Case
  use Placebo
  import SmartCity.TestHelper

  describe "start_link/1" do
    test "should start all datasets in view state" do
      ingestion1 = {:id, "Ingestion One"}
      ingestion2 = {:id, "Ingestion Two"}
      allow Brook.get_all_values!(any(), :ingestions), return: [ingestion1, ingestion2]
      allow Alchemist.IngestionProcessor.start(any()), return: :does_not_matter

      {:ok, _pid} = Alchemist.Init.start_link(monitor: self())

      eventually(fn ->
        assert_called(Alchemist.IngestionProcessor.start(ingestion1))
        assert_called(Alchemist.IngestionProcessor.start(ingestion2))
        assert num_calls(Alchemist.IngestionProcessor.start(any())) == 2
      end)
    end
  end
end

defmodule Alchemist.InitTest do
  use ExUnit.Case
  use Placebo
  import SmartCity.TestHelper

  describe "start_link/1" do
    test "should start all datasets in view state" do
      dataset1 = {:id, "Dataset One"}
      dataset2 = {:id, "Dataset Two"}
      allow Brook.get_all_values!(any(), :datasets), return: [dataset1, dataset2]
      allow Alchemist.IngestionProcessor.start(any()), return: :does_not_matter

      {:ok, _pid} = Alchemist.Init.start_link(monitor: self())

      eventually(fn ->
        assert_called(Alchemist.IngestionProcessor.start(dataset1))
        assert_called(Alchemist.IngestionProcessor.start(dataset2))
        assert num_calls(Alchemist.IngestionProcessor.start(any())) == 2
      end)
    end
  end
end

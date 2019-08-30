defmodule Valkyrie.InitTest do
  use ExUnit.Case
  use Placebo
  import SmartCity.TestHelper

  describe "start_link/1" do
    test "should start all datasets in view state" do
      dataset1 = {:id, "Dataset One"}
      dataset2 = {:id, "Dataset Two"}
      allow Brook.get_all_values!(:datasets), return: [dataset1, dataset2]
      allow Valkyrie.DatasetProcessor.start(any()), return: :does_not_matter

      {:ok, pid} = Valkyrie.Init.start_link([])

      eventually(fn ->
        assert_called(Valkyrie.DatasetProcessor.start(dataset1))
        assert_called(Valkyrie.DatasetProcessor.start(dataset2))
        assert num_calls(Valkyrie.DatasetProcessor.start(any())) == 2
        assert Process.alive?(pid) == false
      end)
    end
  end
end

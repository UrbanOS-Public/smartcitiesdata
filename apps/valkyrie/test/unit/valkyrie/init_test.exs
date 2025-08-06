defmodule Valkyrie.InitTest do
  use ExUnit.Case
  import Mock
  import SmartCity.TestHelper

  describe "start_link/1" do
    test "should start all datasets in view state" do
      dataset1 = {:id, "Dataset One"}
      dataset2 = {:id, "Dataset Two"}
      
      with_mocks([
        {Brook, [], [get_all_values!: fn _, :datasets -> [dataset1, dataset2] end]},
        {Valkyrie.DatasetProcessor, [], [start: fn _ -> :does_not_matter end]}
      ]) do
        {:ok, _pid} = Valkyrie.Init.start_link(monitor: self())

        eventually(fn ->
          assert_called Valkyrie.DatasetProcessor.start(dataset1)
          assert_called Valkyrie.DatasetProcessor.start(dataset2)
          assert_called_exactly(Valkyrie.DatasetProcessor.start(:_), 2)
        end)
      end
    end
  end
end

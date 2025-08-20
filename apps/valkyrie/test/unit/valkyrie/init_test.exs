defmodule Valkyrie.InitTest do
  use ExUnit.Case
  import SmartCity.TestHelper

  describe "start_link/1" do
    test "should start all datasets in view state" do
      dataset1 = {:id, "Dataset One"}
      dataset2 = {:id, "Dataset Two"}
      
      # Setup mocks
      :meck.new(Brook, [:passthrough])
      :meck.new(Valkyrie.DatasetProcessor, [:passthrough])
      
      :meck.expect(Brook, :get_all_values!, fn _, :datasets -> [dataset1, dataset2] end)
      :meck.expect(Valkyrie.DatasetProcessor, :start, fn _ -> :does_not_matter end)
      
      {:ok, _pid} = Valkyrie.Init.start_link(monitor: self())

      eventually(fn ->
        assert :meck.num_calls(Valkyrie.DatasetProcessor, :start, [dataset1]) == 1
        assert :meck.num_calls(Valkyrie.DatasetProcessor, :start, [dataset2]) == 1
        assert :meck.num_calls(Valkyrie.DatasetProcessor, :start, :_) == 2
      end)
      
      # Cleanup
      :meck.unload(Brook)
      :meck.unload(Valkyrie.DatasetProcessor)
    end
  end
end

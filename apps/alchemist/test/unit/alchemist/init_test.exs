defmodule Alchemist.InitTest do
  use ExUnit.Case

  import SmartCity.TestHelper
  import Mock

  describe "start_link/1" do
    test "should start all datasets in view state" do
      ingestion1 = {:id, "Ingestion One"}
      ingestion2 = {:id, "Ingestion Two"}

      with_mocks([
        {Brook, [], [get_all_values!: fn(_, :ingestions) -> [ingestion1, ingestion2] end]},
        {Alchemist.IngestionProcessor, [], [start: fn(_) -> :does_not_matter end]}
      ]) do
        {:ok, _pid} = Alchemist.Init.start_link(monitor: self())

        eventually(fn ->
          assert_called(Alchemist.IngestionProcessor.start(ingestion1))
          assert_called(Alchemist.IngestionProcessor.start(ingestion2))
          assert_called_exactly(Alchemist.IngestionProcessor.start(:_), 2)
        end)
      end
    end
  end
end

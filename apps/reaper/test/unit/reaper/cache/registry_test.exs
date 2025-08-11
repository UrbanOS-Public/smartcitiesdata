defmodule Reaper.Cache.RegistryTest do
  use ExUnit.Case

  setup do
    TestHelper.start_horde()
    :ok
  end

  describe "lookup/1" do
    test "should retrieve the pid for the given cache server" do
      {:ok, pid} = Agent.start_link(fn -> 0 end, name: {:via, Horde.Registry, {Reaper.Cache.Registry, :agent}})

      # Wait for registration to complete in distributed registry
      :timer.sleep(50)
      
      # Ensure the registration actually worked
      lookup_result = Reaper.Cache.Registry.lookup(:agent)
      assert pid == lookup_result, "Expected #{inspect(pid)}, got #{inspect(lookup_result)}"
      
      # Clean up
      Agent.stop(pid)
    end

    test "should return nil for a pid that is not started" do
      assert nil == Reaper.Cache.Registry.lookup(:agent)
    end
  end
end

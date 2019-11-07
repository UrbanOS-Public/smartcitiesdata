defmodule Reaper.Cache.RegistryTest do
  use ExUnit.Case

  setup do
    TestHelper.start_horde()
    :ok
  end

  describe "lookup/1" do
    test "should retrieve the pid for the given cache server" do
      {:ok, pid} = Agent.start_link(fn -> 0 end, name: {:via, Horde.Registry, {Reaper.Cache.Registry, :agent}})

      assert pid == Reaper.Cache.Registry.lookup(:agent)
    end

    test "should return nil for a pid that is not started" do
      assert nil == Reaper.Cache.Registry.lookup(:agent)
    end
  end
end

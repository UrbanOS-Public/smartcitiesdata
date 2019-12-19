defmodule DiscoveryStreams.CachexSupervisorTest do
  use ExUnit.Case
  use TemporaryEnv

  alias DiscoveryStreams.CachexSupervisor

  describe "create_cache/1" do
    test "creates new cachex" do
      assert Cachex.count(:cache_1) == {:error, :no_cache}

      CachexSupervisor.create_cache(:cache_1)

      assert Cachex.count(:cache_1) == {:ok, 0}
    end

    test "cache gets created as a ttl based cache" do
      TemporaryEnv.put :discovery_streams, :ttl, 200 do
        CachexSupervisor.create_cache(:cache_2)

        Cachex.put(:cache_2, :hello, "Brian")

        assert Cachex.get(:cache_2, :hello) == {:ok, "Brian"}
        Process.sleep(201)
        assert Cachex.get(:cache_2, :hello) == {:ok, nil}
      end
    end
  end
end

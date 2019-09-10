defmodule Reaper.Cache.ServerTest do
  use ExUnit.Case

  alias Reaper.Cache.Server

  setup do
    {:ok, pid} = Server.start_link(name: __MODULE__)

    on_exit(fn ->
      ref = Process.monitor(pid)
      Process.exit(pid, :normal)
      assert_receive {:DOWN, ^ref, _, _, _}
    end)

    [cache: pid]
  end

  describe "put/2" do
    test "stores value in the cache", %{cache: cache} do
      GenServer.cast(cache, {:put, "value"})

      assert true == GenServer.call(cache, {:exists?, "value"})
    end

    test "keeps up to the configured size in the cache", %{cache: cache} do
      Enum.each(1..2_003, fn i -> GenServer.cast(cache, {:put, i}) end)

      assert false == GenServer.call(cache, {:exists?, 1})
      assert false == GenServer.call(cache, {:exists?, 2})
      assert false == GenServer.call(cache, {:exists?, 3})
      assert true == GenServer.call(cache, {:exists?, 4})
      assert true == GenServer.call(cache, {:exists?, 5})
    end
  end

  describe "exists?/2" do
    test "returns false when value not in cache", %{cache: cache} do
      assert false == GenServer.call(cache, {:exists?, "value"})
    end
  end
end

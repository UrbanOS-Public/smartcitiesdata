defmodule Reaper.CacheTest do
  use ExUnit.Case
  import Mox
  import Checkov
  alias Reaper.Cache
  alias Reaper.Cache.Server

  @cache :test_cache_1

  setup :verify_on_exit!

  setup do
    {:ok, registry} = Horde.Registry.start_link(keys: :unique, name: Reaper.Cache.Registry)
    {:ok, server} = Server.start_link(name: {:via, Horde.Registry, {Reaper.Cache.Registry, @cache}})

    # Stub successful JSON encoding for normal test cases
    stub(JasonMock, :encode, fn value -> Jason.encode(value) end)

    on_exit(fn ->
      kill(server)
      kill(registry)
    end)

    :ok
  end

  describe "mark_duplicates/2" do
    data_test "returns #{inspect(result)} with message #{inspect(message)} and cache contains #{inspect(cache_entry)}" do
      Cache.cache(@cache, cache_entry)

      assert result == Cache.mark_duplicates(@cache, message)

      where([
        [:cache_entry, :message, :result],
        ["hello", "hello", {:duplicate, "hello"}],
        [%{my: "world"}, %{my: "world"}, {:duplicate, %{my: "world"}}],
        ["no_match", "new_stuff", {:ok, "new_stuff"}]
      ])
    end

    test "returns {:error, {:json, reason}} when Jason.encode! returns an error" do
      expect(JasonMock, :encode, fn _ -> {:error, :some_reason} end)
      assert {:error, {:json, :some_reason}} == Cache.mark_duplicates(@cache, {:un, :encodable})
    end
  end

  describe "cache/2" do
    test "add md5 of value to cache" do
      assert {:ok, true} == Cache.cache(@cache, "hello")

      assert true ==
               GenServer.call(
                 {:via, Horde.Registry, {Reaper.Cache.Registry, @cache}},
                 {:exists?, "5DEAEE1C1332199E5B5BC7C5E4F7F0C2"}
               )
    end

    test "returns {:error, {:json, reason}} when Jason.encode! returns an error" do
      expect(JasonMock, :encode, fn _ -> {:error, :some_reason} end)
      assert {:error, {:json, :some_reason}} == Cache.cache(@cache, {:un, :encodable})
    end
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end

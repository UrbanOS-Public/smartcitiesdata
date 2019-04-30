defmodule Reaper.CacheTest do
  use ExUnit.Case
  use Placebo
  import Checkov
  alias Reaper.Cache

  @cache :test_cache_1

  setup do
    Cachex.start_link(@cache)
    :ok
  end

  describe "cache/2" do
    data_test "add md5 of value to cache" do
      Cache.cache(@cache, value)

      assert {:ok, result} == Cachex.exists?(@cache, key)

      where([
        [:value, :key, :result],
        [{:ok, "hello"}, "5DEAEE1C1332199E5B5BC7C5E4F7F0C2", true],
        [{:error, "hello"}, "5DEAEE1C1332199E5B5BC7C5E4F7F0C2", false]
      ])
    end
  end

  describe "duplicate?/2" do
    data_test "returns #{result} with message #{inspect(message)} and cache contains #{inspect(cache_entry)}" do
      Cache.cache(@cache, {:ok, cache_entry})

      assert result == Cache.duplicate?(message, @cache)

      where([
        [:cache_entry, :message, :result],
        ["hello", "hello", true],
        [%{my: "world"}, %{my: "world"}, true],
        ["no_match", "new_stuff", false]
      ])
    end
  end
end

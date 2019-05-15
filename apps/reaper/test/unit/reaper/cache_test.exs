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

    test "raises exception when Cachex returns an error" do
      allow Cachex.exists?(any(), any()), return: {:error, "some_reason"}

      assert_raise Cache.CacheError, "some_reason", fn ->
        Cache.mark_duplicates(@cache, "dumb value")
      end
    end

    test "returns {:error, {:json, reason}} when Jason.encode! returns an error" do
      allow Jason.encode(any()), return: {:error, :some_reason}
      assert {:error, {:json, :some_reason}} == Cache.mark_duplicates(@cache, {:un, :encodable})
    end
  end

  describe "cache/2" do
    test "add md5 of value to cache" do
      assert {:ok, true} == Cache.cache(@cache, "hello")

      assert {:ok, true} == Cachex.exists?(@cache, "5DEAEE1C1332199E5B5BC7C5E4F7F0C2")
    end

    test "returns {:error, {:cachex, reason}} when Cachex returns an error" do
      allow Cachex.put(any(), any(), any()), return: {:error, "some_reason"}

      assert_raise Cache.CacheError, "some_reason", fn ->
        Cache.cache(@cache, "dumb value")
      end
    end

    test "returns {:error, {:json, reason}} when Jason.encode! returns an error" do
      allow Jason.encode(any()), return: {:error, :some_reason}
      assert {:error, {:json, :some_reason}} == Cache.cache(@cache, {:un, :encodable})
    end
  end
end

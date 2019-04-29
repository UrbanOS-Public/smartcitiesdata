defmodule Reaper.CacheTest do
  use ExUnit.Case
  use Placebo
  import Checkov
  alias Reaper.Cache

  describe ".cache" do
    test "it caches data with a md5sum of its content" do
      Cachex.start_link(:test_cache_one)

      records = Cache.cache([{:ok, "hello"}, {:ok, %{my: "world"}}, {:ok, "hello"}], :test_cache_one)

      assert Enum.into(records, []) == [{:ok, "hello"}, {:ok, %{my: "world"}}, {:ok, "hello"}]
      assert Cachex.size!(:test_cache_one) == 2
      assert Cachex.exists?(:test_cache_one, "5D41402ABC4B2A76B9719D911017C592")
      assert Cachex.exists?(:test_cache_one, "078AEA799F191F012B11BA93F5E05975")
    end

    @tag capture_log: true
    test "it doesn't cache data that failed to load" do
      Cachex.start_link(:test_cache_two)

      records = Cache.cache([{:error, "bad_hello"}, {:ok, "hello"}], :test_cache_two)
      assert Enum.into(records, []) == [{:error, "bad_hello"}, {:ok, "hello"}]
      assert Cachex.size!(:test_cache_two) == 1
    end
  end

  describe "duplicate?" do
    data_test "returns #{result} with message #{inspect(message)} and cache contains #{inspect(cache_entry)}" do
      cache_name = :test_cache_three
      Cachex.start_link(cache_name)

      Stream.run(Cache.cache([{:ok, cache_entry}], cache_name))

      assert result == Cache.duplicate?(message, cache_name)

      where([
        [:cache_entry, :message, :result],
        ["hello", "hello", true],
        [%{my: "world"}, %{my: "world"}, true],
        ["no_match", "new_stuff", false]
      ])
    end
  end
end

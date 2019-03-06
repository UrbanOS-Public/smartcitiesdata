defmodule Reaper.CacheTest do
  use ExUnit.Case
  use Placebo
  alias Reaper.Cache

  describe ".cache" do
    test "it caches data with a md5sum of its content" do
      Cachex.start_link(:test_cache_one)

      records = Cache.cache([{:ok, "hello"}, {:ok, %{my: "world"}}, {:ok, "hello"}], :test_cache_one)

      assert Cachex.size!(:test_cache_one) == 2
      assert Cachex.exists?(:test_cache_one, "5D41402ABC4B2A76B9719D911017C592")
      assert Cachex.exists?(:test_cache_one, "078AEA799F191F012B11BA93F5E05975")
      assert records == [{:ok, "hello"}, {:ok, %{my: "world"}}, {:ok, "hello"}]
    end

    @tag capture_log: true
    test "it doesn't cache data that failed to load" do
      Cachex.start_link(:test_cache_two)

      records = Cache.cache([{:error, "bad_hello"}, {:ok, "hello"}], :test_cache_two)
      assert Cachex.size!(:test_cache_two) == 1
      assert records == [{:error, "bad_hello"}, {:ok, "hello"}]
    end
  end

  describe ".dedupe" do
    test "it filters out data that is already in the cache (based on md5sum)" do
      Cachex.start_link(:test_cache_three)

      Cache.cache([{:ok, "hello"}, {:ok, %{my: "world"}}], :test_cache_three)

      assert Cache.dedupe(["hello", %{my: "world"}, "new stuff"], :test_cache_three) == [
               "new stuff"
             ]
    end
  end
end

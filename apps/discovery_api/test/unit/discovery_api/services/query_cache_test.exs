defmodule DiscoveryApi.Services.QueryCacheTest do
  use ExUnit.Case
  use Placebo

  alias DiscoveryApi.Services.QueryCache

  @query "SELECT id, name FROM test_table"
  @rows [%{"id" => 1, "name" => "Alice"}, %{"id" => 2, "name" => "Bob"}]

  describe "cache_key/1" do
    test "is prefixed with discovery_api:trino_cache:" do
      assert String.starts_with?(QueryCache.cache_key(@query), "discovery_api:trino_cache:")
    end

    test "is deterministic for the same query" do
      assert QueryCache.cache_key(@query) == QueryCache.cache_key(@query)
    end

    test "differs for different queries" do
      refute QueryCache.cache_key(@query) == QueryCache.cache_key("SELECT * FROM other")
    end
  end

  describe "fetch_or_execute/2 — cache hit" do
    test "returns cached rows and :cache_hit without calling execute_fn" do
      allow(Redix.command(:redix, ["GET", any()]), return: {:ok, Jason.encode!(@rows)})
      allow(Redix.command(:redix, ["INCR", any()]), return: {:ok, 1})

      result = QueryCache.fetch_or_execute(@query, fn -> raise "should not be called" end)

      assert {:ok, @rows, :cache_hit} == result
      assert_called(Redix.command(:redix, ["INCR", "discovery_api:trino_cache:hits"]))
    end
  end

  describe "fetch_or_execute/2 — cache miss" do
    test "calls execute_fn, writes SETEX, and returns :cache_miss" do
      allow(Redix.command(:redix, ["GET", any()]), return: {:ok, nil})
      allow(Redix.command(:redix, ["SETEX", any(), any(), any()]), return: {:ok, "OK"})
      allow(Redix.command(:redix, ["INCR", any()]), return: {:ok, 1})

      assert {:ok, @rows, :cache_miss} == QueryCache.fetch_or_execute(@query, fn -> {:ok, @rows} end)

      assert_called(Redix.command(:redix, ["SETEX", QueryCache.cache_key(@query), 360, Jason.encode!(@rows)]))
      assert_called(Redix.command(:redix, ["INCR", "discovery_api:trino_cache:misses"]))
    end

    test "skips SETEX when row count exceeds max_rows" do
      Application.put_env(:discovery_api, :query_cache, max_rows: 1)
      on_exit(fn -> Application.delete_env(:discovery_api, :query_cache) end)

      allow(Redix.command(:redix, ["GET", any()]), return: {:ok, nil})
      allow(Redix.command(:redix, ["INCR", any()]), return: {:ok, 1})

      assert {:ok, @rows, :cache_miss} == QueryCache.fetch_or_execute(@query, fn -> {:ok, @rows} end)

      assert_called(Redix.command(:redix, ["SETEX", any(), any(), any()]), times(0))
    end

    test "propagates execute_fn error tuple without writing to Redis" do
      allow(Redix.command(:redix, ["GET", any()]), return: {:ok, nil})

      assert {:error, "trino down"} == QueryCache.fetch_or_execute(@query, fn -> {:error, "trino down"} end)

      assert_called(Redix.command(:redix, ["SETEX", any(), any(), any()]), times(0))
      assert_called(Redix.command(:redix, ["INCR", any()]), times(0))
    end
  end

  describe "fetch_or_execute/2 — Redis failures" do
    test "treats a Redis GET error as a cache miss and still executes" do
      allow(Redix.command(:redix, ["GET", any()]), return: {:error, :econnrefused})
      allow(Redix.command(:redix, ["SETEX", any(), any(), any()]), return: {:ok, "OK"})
      allow(Redix.command(:redix, ["INCR", any()]), return: {:ok, 1})

      assert {:ok, @rows, :cache_miss} == QueryCache.fetch_or_execute(@query, fn -> {:ok, @rows} end)
    end

    test "does not raise when Redis SETEX fails" do
      allow(Redix.command(:redix, ["GET", any()]), return: {:ok, nil})
      allow(Redix.command(:redix, ["SETEX", any(), any(), any()]), return: {:error, :econnrefused})
      allow(Redix.command(:redix, ["INCR", any()]), return: {:ok, 1})

      assert {:ok, @rows, :cache_miss} == QueryCache.fetch_or_execute(@query, fn -> {:ok, @rows} end)
    end

    test "treats malformed cached JSON as a cache miss" do
      allow(Redix.command(:redix, ["GET", any()]), return: {:ok, "not valid json {"})
      allow(Redix.command(:redix, ["SETEX", any(), any(), any()]), return: {:ok, "OK"})
      allow(Redix.command(:redix, ["INCR", any()]), return: {:ok, 1})

      assert {:ok, @rows, :cache_miss} == QueryCache.fetch_or_execute(@query, fn -> {:ok, @rows} end)
    end
  end
end

defmodule DiscoveryApi.Services.QueryCache do
  @moduledoc false

  @redix_module Application.compile_env(:discovery_api, :redix_module, Redix)

  @prefix "discovery_api:trino_cache:"
  @ttl_seconds 360
  @hits_key "discovery_api:trino_cache:hits"
  @misses_key "discovery_api:trino_cache:misses"

  def cache_key(query_string) do
    hash = :crypto.hash(:md5, query_string) |> Base.encode16()
    @prefix <> hash
  end

  # Checks the cache for query_string. On a hit returns {:ok, rows, :cache_hit}.
  # On a miss calls execute_fn.() which must return {:ok, [map()]} | {:error, reason},
  # stores a successful result, then returns {:ok, rows, :cache_miss}.
  # Redis failures degrade gracefully — they never prevent query execution.
  def fetch_or_execute(query_string, execute_fn) do
    key = cache_key(query_string)

    case get_cached(key) do
      {:ok, rows} ->
        @redix_module.command(:redix, ["INCR", @hits_key])
        {:ok, rows, :cache_hit}

      :miss ->
        case execute_fn.() do
          {:ok, rows} ->
            store(key, rows)
            @redix_module.command(:redix, ["INCR", @misses_key])
            {:ok, rows, :cache_miss}

          error ->
            error
        end
    end
  end

  defp get_cached(key) do
    case @redix_module.command(:redix, ["GET", key]) do
      {:ok, nil} ->
        :miss

      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, rows} -> {:ok, rows}
          _ -> :miss
        end

      _ ->
        :miss
    end
  end

  defp store(key, rows) do
    max = Application.get_env(:discovery_api, :query_cache, []) |> Keyword.get(:max_rows, 50_000)

    if length(rows) <= max do
      case Jason.encode(rows) do
        {:ok, json} -> @redix_module.command(:redix, ["SETEX", key, @ttl_seconds, json])
        _ -> :noop
      end
    end
  end
end

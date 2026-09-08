defmodule DiscoveryApi.Stats.QueryStats do
  @moduledoc false
  use Agent

  @redix_module Application.compile_env(:discovery_api, :redix_module, Redix)

  def start_link(_opts) do
    Agent.start_link(fn -> initial_state() end, name: __MODULE__)
  end

  # Records a query execution. `sql` is hashed (MD5) for uniqueness tracking;
  # `duration_ms` is added to both the per-hash and overall totals.
  def record(sql, duration_ms) do
    hash = :crypto.hash(:md5, sql) |> Base.encode16()

    Agent.update(__MODULE__, fn state ->
      entry = Map.get(state.query_data, hash, %{count: 0, total_ms: 0})

      %{
        state
        | query_data: Map.put(state.query_data, hash, %{count: entry.count + 1, total_ms: entry.total_ms + duration_ms}),
          total_count: state.total_count + 1,
          total_duration_ms: state.total_duration_ms + duration_ms
      }
    end)
  end

  def record_caller(caller_id) do
    Agent.update(__MODULE__, fn state ->
      %{state | caller_counts: Map.update(state.caller_counts, caller_id, 1, &(&1 + 1))}
    end)
  end

  def stats do
    query_stats =
      Agent.get(__MODULE__, fn state ->
        overall_avg =
          if state.total_count > 0,
            do: state.total_duration_ms / state.total_count,
            else: 0.0

        per_query_avgs =
          Map.new(state.query_data, fn {hash, %{count: count, total_ms: total_ms}} ->
            {hash, total_ms / count}
          end)

        %{
          unique_query_count: map_size(state.query_data),
          total_query_count: state.total_count,
          overall_avg_duration_ms: overall_avg,
          per_query_avg_duration_ms: per_query_avgs,
          caller_counts: state.caller_counts
        }
      end)

    hits = read_counter("discovery_api:trino_cache:hits")
    misses = read_counter("discovery_api:trino_cache:misses")
    total = hits + misses
    hit_ratio = if total > 0, do: Float.round(hits / total, 4), else: 0.0

    Map.merge(query_stats, %{
      cache_hits: hits,
      cache_misses: misses,
      cache_hit_ratio: hit_ratio
    })
  end

  defp read_counter(key) do
    case @redix_module.command(:redix, ["GET", key]) do
      {:ok, nil} -> 0
      {:ok, val} -> String.to_integer(val)
      _ -> 0
    end
  end

  def reset do
    Agent.update(__MODULE__, fn _ -> initial_state() end)
  end

  # Wraps a lazy Prestige stream so that elapsed time is recorded when the
  # stream is fully consumed or halted (via Stream.transform/4 after_fun).
  def wrap_stream(stream, sql) do
    Stream.transform(
      stream,
      fn -> System.monotonic_time(:millisecond) end,
      fn item, start_ms -> {[item], start_ms} end,
      fn start_ms ->
        duration_ms = System.monotonic_time(:millisecond) - start_ms
        Task.start(fn -> record(sql, duration_ms) end)
      end
    )
  end

  defp initial_state do
    %{query_data: %{}, total_count: 0, total_duration_ms: 0, caller_counts: %{}}
  end
end

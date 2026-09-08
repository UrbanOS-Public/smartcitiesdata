defmodule DiscoveryApi.Services.MetricsService do
  @moduledoc """
  Service that collects metrics and records them to the application's metric through telemetry (which by default is prometheus)
  """

  require Logger

  @redix_module Application.compile_env(:discovery_api, :redix_module, Redix)

  def record_csv_download_count_metrics(dataset_id, table_name) do
    [
      app: "discovery_api",
      DatasetId: dataset_id,
      Table: table_name
    ]
    |> TelemetryEvent.add_event_metrics([:downloaded_csvs])
  end

  def record_query_metrics(dataset_id, table_name, return_type) do
    [
      app: "discovery_api",
      DatasetId: dataset_id,
      Table: table_name,
      ContentType: return_type
    ]
    |> TelemetryEvent.add_event_metrics([:data_queries])
  end

  def record_api_hit(request_type, dataset_id) do
    Redix.command!(:redix, ["INCR", "smart_registry:#{request_type}:count:#{dataset_id}"])
  end

  def flush_query_stats_to_redis do
    stats = DiscoveryApi.Stats.QueryStats.stats()
    json = Jason.encode!(stats)

    @redix_module.command!(:redix, ["SET", "discovery_api:query_stats", json])

    Logger.info(
      "Query stats flushed to Redis — unique=#{stats.unique_query_count} total=#{stats.total_query_count}" <>
        " overall_avg_ms=#{Float.round(stats.overall_avg_duration_ms, 2)}" <>
        " cache_hits=#{stats.cache_hits} cache_misses=#{stats.cache_misses} hit_ratio=#{stats.cache_hit_ratio}" <>
        " unique_callers=#{map_size(stats.caller_counts)}"
    )
  end
end

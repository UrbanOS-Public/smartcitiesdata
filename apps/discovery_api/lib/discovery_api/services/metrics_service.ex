require Logger

defmodule DiscoveryApi.Services.MetricsService do
  @moduledoc """
  Service that collects metrics and records them to the application's metric collector (which by default is prometheus)
  """
  def record_csv_download_count_metrics(dataset_id, table_name) do
    [
      app: "discovery_api",
      DatasetId: dataset_id,
      Table: table_name
    ]
    |> TelemetryEvent.add_event_count([:downloaded_csvs])
  end

  def record_query_metrics(dataset_id, table_name, return_type) do
    [
      app: "discovery_api",
      DatasetId: dataset_id,
      Table: table_name,
      ContentType: return_type
    ]
    |> TelemetryEvent.add_event_count([:data_queries])
  end

  def record_api_hit(request_type, dataset_id) do
    Redix.command!(:redix, ["INCR", "smart_registry:#{request_type}:count:#{dataset_id}"])
  end
end

defmodule DiscoveryApiWeb.DatasetStatsController do
  @moduledoc """
  Provides a controller endpoint for getting dataset statistics for a single dataset
  """
  use DiscoveryApiWeb, :controller

  def fetch_dataset_stats(conn, _params) do
    dataset_id = conn.assigns.model.id
    render(conn, :fetch_dataset_stats, model: get_stats_model(dataset_id))
  end

  defp get_stats_model(dataset_id) do
    case DiscoveryApi.Data.Persistence.get("discovery-api:stats:#{dataset_id}") do
      nil -> %{}
      stats -> Jason.decode!(stats)
    end
  end
end

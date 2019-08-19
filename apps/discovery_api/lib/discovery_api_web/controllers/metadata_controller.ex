defmodule DiscoveryApiWeb.MetadataController do
  use DiscoveryApiWeb, :controller

  alias DiscoveryApi.Data.Model

  plug(:accepts, DiscoveryApiWeb.MetadataView.accepted_formats())
  plug(DiscoveryApiWeb.Plugs.GetModel)
  plug(DiscoveryApiWeb.Plugs.Restrictor)

  def fetch_detail(conn, _params) do
    render(conn, :detail, model: conn.assigns.model)
  end

  def fetch_schema(conn, _params) do
    render(conn, :fetch_schema, model: conn.assigns.model)
  end

  def fetch_metrics(conn, _params) do
    dataset_id = conn.assigns.model.id
    metrics = Model.get_count_maps(dataset_id)

    json(conn, metrics)
  end

  def fetch_stats(conn, _params) do
    dataset_id = conn.assigns.model.id
    stats = get_stats_model(dataset_id)

    json(conn, stats)
  end

  defp get_stats_model(dataset_id) do
    case DiscoveryApi.Data.Persistence.get("discovery-api:stats:#{dataset_id}") do
      nil -> %{}
      stats -> Jason.decode!(stats)
    end
  end
end

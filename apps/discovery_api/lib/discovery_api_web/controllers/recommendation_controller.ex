defmodule DiscoveryApiWeb.RecommendationController do
  use DiscoveryApiWeb, :controller

  plug(DiscoveryApiWeb.Plugs.GetModel)

  def recommendations(conn, _params) do
    json(conn, DiscoveryApi.RecommendationEngine.get_recommendations(conn.assigns.model))
  end
end

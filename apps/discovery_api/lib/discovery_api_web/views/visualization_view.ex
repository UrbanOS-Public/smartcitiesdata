defmodule DiscoveryApiWeb.VisualizationView do
  use DiscoveryApiWeb, :view

  def accepted_formats() do
    ["json"]
  end

  def render("visualization.json", %{visualization: visualization}) do
    %{
      id: visualization.public_id,
      title: visualization.title,
      query: visualization.query
    }
  end
end

defmodule DiscoveryApiWeb.VisualizationView do
  use DiscoveryApiWeb, :view

  def accepted_formats() do
    ["json"]
  end

  def render("visualization.json", %{visualization: visualization}), do: visualization_response(visualization)

  def render("visualizations.json", %{visualizations: visualizations}) do
    Enum.map(visualizations, &visualization_response/1)
  end

  defp visualization_response(visualization) do
    %{
      id: visualization.public_id,
      title: visualization.title,
      query: visualization.query,
      chart: safely_decode(visualization.chart),
      created: visualization.inserted_at,
      updated: visualization.updated_at
    }
  end

  defp safely_decode(nil), do: %{}

  defp safely_decode(chart) do
    case Jason.decode(chart) do
      {:ok, decoded} -> decoded
      _ -> %{}
    end
  end
end

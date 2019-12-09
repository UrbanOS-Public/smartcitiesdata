defmodule DiscoveryApiWeb.VisualizationView do
  use DiscoveryApiWeb, :view

  def accepted_formats() do
    ["json"]
  end

  def render("visualization.json", %{visualization: visualization}) do
    %{
      id: visualization.public_id,
      title: visualization.title,
      query: visualization.query,
      chart: safely_decode(visualization.chart)
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

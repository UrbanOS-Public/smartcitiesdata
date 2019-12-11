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

  def render("visualizations.json", %{visualizations: visualizations}) do
    visualizations
    |> Enum.map(fn visualization ->
      %{
        id: visualization.public_id,
        title: visualization.title,
        query: visualization.query,
        chart: safely_decode(visualization.chart),
        created: visualization.inserted_at,
        updated: visualization.updated_at
      }
    end)
  end

  defp safely_decode(nil), do: %{}

  defp safely_decode(chart) do
    case Jason.decode(chart) do
      {:ok, decoded} -> decoded
      _ -> %{}
    end
  end
end

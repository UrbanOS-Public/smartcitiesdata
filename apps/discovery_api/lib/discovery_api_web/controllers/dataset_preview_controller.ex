defmodule DiscoveryApiWeb.DatasetPreviewController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApiWeb.Services.PrestoService

  def fetch_preview(conn, _params) do
    columns =
      conn.assigns.model.systemName
      |> PrestoService.preview_columns()

    conn.assigns.model.systemName
    |> PrestoService.preview()
    |> return_preview(columns, conn)
  rescue
    _e in Prestige.Error -> json(conn, %{data: [], meta: %{columns: []}, message: "Something went wrong while fetching the preview."})
  end

  def fetch_geojson_features(conn, _params) do
    dataset_name = conn.assigns.model.systemName

    features =
      PrestoService.preview(dataset_name, 10)
      |> Enum.map(&decode_feature_result(&1))

    render(conn, "features.json", %{features: features, dataset_name: dataset_name})
  end

  defp decode_feature_result(feature) do
    feature
    |> Map.get("feature")
    |> Jason.decode!()
  end

  defp return_preview(rows, columns, conn), do: json(conn, %{data: rows, meta: %{columns: columns}})
end

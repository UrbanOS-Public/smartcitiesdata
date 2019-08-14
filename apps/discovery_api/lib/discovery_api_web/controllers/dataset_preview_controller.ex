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
    _e in Prestige.Error ->
      json(conn, %{
        data: [],
        meta: %{columns: []},
        message: "Something went wrong while fetching the preview."
      })
  end

  def fetch_geojson_features(conn, _params) do
    dataset_name = conn.assigns.model.systemName

    features =
      PrestoService.preview(dataset_name, 10)
      |> Enum.map(&decode_feature_result(&1))

    bbox = calculate_bounding_box(features)

    render(conn, "features.json", %{features: features, dataset_name: dataset_name, bbox: bbox})
  end

  defp decode_feature_result(feature) do
    feature
    |> Map.get("feature")
    |> Jason.decode!()
  end

  defp return_preview(rows, columns, conn),
    do: json(conn, %{data: rows, meta: %{columns: columns}})

  defp calculate_bounding_box(features_list) do
    coords = []

    features_list
    |> Enum.reduce(coords, fn %{"geometry" => %{"coordinates" => coordinates}}, coords ->
      [coordinates | coords]
    end)
    |> reduce_coordinates()
    |> List.flatten()
    |> Enum.reduce([nil, nil, nil, nil], fn {x, y}, acc -> update_bbox(x, y, acc) end)
  end

  defp update_bbox(x, y, [min_x, min_y, max_x, max_y]) do
    [
      min(x, min_x),
      min(y, min_y),
      get_max(x, max_x),
      get_max(y, max_y)
    ]
  end

  defp get_max(a, nil), do: a
  defp get_max(a, b), do: max(a, b)

  defp reduce_coordinates([x, y]) when is_list(x) == false do
    {x, y}
  end

  defp reduce_coordinates(coords) do
    Enum.map(coords, &reduce_coordinates/1)
  end
end

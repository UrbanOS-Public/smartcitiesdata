defmodule DiscoveryApiWeb.Utilities.GeojsonUtils do
  @moduledoc """
    This module handles calculating the bounding box for a list of features in a GeoJson strucutre
  """

  def calculate_bounding_box(features_list, bounding_box \\ [nil, nil, nil, nil])

  def calculate_bounding_box(
        %{"geometry" => %{"coordinates" => coordinates}},
        bounding_box
      ) do
    coordinates
    |> reduce_coordinates()
    |> List.wrap()
    |> List.flatten()
    |> Enum.reduce(bounding_box, &update_bounding_box/2)
    |> handle_empty_bounding_box()
  end

  def calculate_bounding_box(features_list, _) when is_list(features_list) do
    coords = []

    features_list
    |> Enum.reduce(coords, fn %{"geometry" => %{"coordinates" => coordinates}}, coords ->
      [coordinates | coords]
    end)
    |> reduce_coordinates()
    |> List.flatten()
    |> Enum.reduce([nil, nil, nil, nil], &update_bounding_box/2)
    |> handle_empty_bounding_box()
  end

  def update_bounding_box({x, y}, [min_x, min_y, max_x, max_y])
      when is_number(x) and is_number(y) do
    [
      min(x, min_x),
      min(y, min_y),
      get_max(x, max_x),
      get_max(y, max_y)
    ]
  end

  def update_bounding_box(_, _), do: raise(MalformedGeometryError)

  defp get_max(a, nil), do: a
  defp get_max(a, b), do: max(a, b)

  defp reduce_coordinates([x, y]) when is_list(x) == false and is_list(y) == false do
    {x, y}
  end

  defp reduce_coordinates(coords) when is_list(coords) do
    Enum.map(coords, &reduce_coordinates/1)
  end

  defp reduce_coordinates(_) do
    raise MalformedGeometryError
  end

  defp handle_empty_bounding_box([nil, nil, nil, nil]), do: nil
  defp handle_empty_bounding_box(bbox), do: bbox
end

defmodule MalformedGeometryError do
  defexception message: "Geometry is malformed. Could not compute bounding box"
end

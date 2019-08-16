defmodule DiscoveryApiWeb.DataView do
  use DiscoveryApiWeb, :view
  import DiscoveryApiWeb.Utilities.StreamUtils
  alias DiscoveryApiWeb.Utilities.GeojsonUtils

  def accepted_formats() do
    ["csv", "json", "geojson"]
  end

  # this is because preview from UI doesn't ask for JSON but expects it
  # get rid of this once we fix the UI
  def accepted_preview_formats() do
    ["json", "csv", "geojson"]
  end

  def render("data.csv", %{rows: rows, columns: columns}) do
    map_data_stream_for_csv(rows, columns)
    |> Enum.join("")
  end

  def render("data.json", %{rows: rows, columns: columns}) do
    %{
      data: rows,
      meta: %{columns: columns}
    }
  end

  def render("data.geojson", %{rows: features, dataset_name: name}) do
    decoded_features = Enum.map(features, &decode_feature_result/1)

    translated = %{
      name: name,
      features: decoded_features,
      type: "FeatureCollection"
    }

    response =
      case GeojsonUtils.calculate_bounding_box(decoded_features) do
        nil -> translated
        bbox -> Map.put(translated, :bbox, bbox)
      end

    Jason.encode!(response)
  end

  def render_as_stream(:data, "csv", %{stream: stream, columns: columns}) do
    map_data_stream_for_csv(stream, columns)
  end

  def render_as_stream(:data, "json", %{stream: stream, columns: columns}) do
    data =
      stream
      |> Stream.map(fn x ->
        Stream.zip(columns, x) |> Enum.into(%{}) |> Jason.encode!()
      end)
      |> Stream.intersperse(",")

    [["["], data, ["]"]]
    |> Stream.concat()
  end

  def render_as_stream(:data, "geojson", %{stream: stream, columns: columns, dataset_name: name}) do
    type = "FeatureCollection"

    data =
      stream
      |> Stream.map(fn x ->
        Stream.zip(columns, x) |> Enum.into(%{})
      end)
      |> Stream.map(&decode_feature_result(&1))
      |> Stream.map(&Jason.encode!/1)
      |> Stream.intersperse(",")

    [["{\"type\": \"#{type}\", \"name\": \"#{name}\", \"features\": "], ["["], data, ["],"]]
    |> Stream.concat()
  end

  defp decode_feature_result(feature) do
    feature
    |> Map.get("feature")
    |> Jason.decode!()
  end
end

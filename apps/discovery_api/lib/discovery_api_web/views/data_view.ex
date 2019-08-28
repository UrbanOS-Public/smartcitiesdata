defmodule DiscoveryApiWeb.DataView do
  use DiscoveryApiWeb, :view
  import DiscoveryApiWeb.Utilities.StreamUtils
  alias DiscoveryApiWeb.Utilities.{GeojsonUtils, JsonFieldDecoder}

  def accepted_formats() do
    ["csv", "json", "geojson"]
  end

  # this is because preview from UI doesn't ask for JSON but expects it
  # get rid of this once we fix the UI
  def accepted_preview_formats() do
    ["json", "csv", "geojson"]
  end

  def render("data.csv", %{rows: rows, columns: columns}) do
    rows = Enum.map(rows, &Map.values/1)

    [columns]
    |> Enum.concat(rows)
    |> map_data_stream_for_csv()
    |> Enum.into([])
    |> List.to_string()
  end

  def render("data.json", %{rows: rows, columns: columns, schema: schema}) do
    rows = Enum.map(rows, &JsonFieldDecoder.decode_one_datum(schema, &1))

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
    rows = Stream.map(stream, &Map.values/1)

    [columns]
    |> Stream.concat(rows)
    |> map_data_stream_for_csv()
  end

  def render_as_stream(:data, "json", %{stream: stream, schema: schema}) do
    data =
      stream
      |> Stream.map(&JsonFieldDecoder.decode_one_datum(schema, &1))
      |> Stream.map(&Jason.encode!/1)
      |> Stream.intersperse(",")

    [["["], data, ["]"]]
    |> Stream.concat()
  end

  def render_as_stream(:data, "geojson", %{stream: stream, dataset_name: name}) do
    type = "FeatureCollection"

    data =
      stream
      |> Stream.map(&Map.get(&1, "feature"))
      # |> Stream.map(&Jason.encode!/1)
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

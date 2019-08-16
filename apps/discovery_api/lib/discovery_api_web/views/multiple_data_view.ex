defmodule DiscoveryApiWeb.MultipleDataView do
  use DiscoveryApiWeb, :view
  import DiscoveryApiWeb.Utilities.StreamUtils

  def accepted_formats() do
    ["csv", "json"]
  end

  def render_as_stream(:data, "json", %{stream: stream}) do
    data =
      stream
      |> Stream.map(&Jason.encode!/1)
      |> Stream.intersperse(",")

    [["["], data, ["]"]]
    |> Stream.concat()
  end

  def render_as_stream(:data, "csv", %{stream: stream}) do
    column_names =
      stream
      |> Stream.take(1)
      |> Stream.map(&Map.keys/1)
      |> Enum.into([])
      |> List.flatten()

    stream
    |> Stream.map(&Map.values/1)
    |> map_data_stream_for_csv(column_names)
  end
end

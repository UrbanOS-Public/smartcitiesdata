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
    stream
    |> Stream.transform(false, &do_transform/2)
    |> map_data_stream_for_csv()
  end

  defp do_transform(el, false) do
    {[Map.keys(el), Map.values(el)], true}
  end

  defp do_transform(el, true) do
    {[Map.values(el)], true}
  end
end

defmodule DiscoveryApiWeb.Utilities.StreamUtils do
  @moduledoc """
  Utilities for streaming chunked data and converting a stream to csv
  """
  alias Plug.Conn
  alias DiscoveryApiWeb.Utilities.GeojsonUtils

  require Logger

  def map_data_stream_for_csv(stream) do
    stream
    |> Stream.map(&flatten_lists/1)
    |> CSV.encode(delimiter: "\n")
  end

  defp flatten_lists(row) do
    Stream.map(row, fn
      column when is_list(column) -> Enum.join(column, ",")
      column -> column
    end)
  end

  def resp_as_stream(conn, stream, format, dataset_id \\ "query-results", hosted? \\ false)
  # sobelow_skip ["XSS.ContentType"]
  def resp_as_stream(conn, stream, "geojson" = format, dataset_id, false = _hosted?) do
    conn =
      conn
      |> Conn.put_resp_content_type(MIME.type(format))
      |> Conn.put_resp_header(
        "content-disposition",
        "attachment; filename=#{dataset_id}.#{format}"
      )
      |> Conn.send_chunked(200)

    {conn, bounding_box} =
      Enum.reduce_while(stream, {conn, [nil, nil, nil, nil]}, fn data, {conn, bounding_box} ->
        case Conn.chunk(conn, data) do
          {:ok, conn} ->
            {:cont, {conn, decode_and_calculate_bounding_box(data, bounding_box)}}

          {:error, :closed} ->
            {:halt, {conn, bounding_box}}
        end
      end)

    {:ok, conn} = Conn.chunk(conn, "\"bbox\": #{Jason.encode!(bounding_box)}}")
    conn
  end

  # sobelow_skip ["XSS.ContentType"]
  def resp_as_stream(conn, stream, format, dataset_id, _hosted?) do
    conn =
      conn
      |> Conn.put_resp_content_type(MIME.type(format))
      |> Conn.put_resp_header("content-disposition", "attachment; filename=#{dataset_id}.#{format}")
      |> Conn.send_chunked(200)

    Enum.reduce_while(stream, conn, fn data, conn ->
      case Conn.chunk(conn, data) do
        {:ok, conn} -> {:cont, conn}
        {:error, :closed} -> {:halt, conn}
      end
    end)
  end

  defp decode_and_calculate_bounding_box(feature_json, bounding_box)
       when is_binary(feature_json) do
    case Jason.decode(feature_json) do
      {:ok, json} -> GeojsonUtils.calculate_bounding_box(json, bounding_box)
      {:error, _} -> bounding_box
    end
  end
end

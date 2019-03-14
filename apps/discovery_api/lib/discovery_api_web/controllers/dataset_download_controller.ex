require Logger

defmodule DiscoveryApiWeb.DatasetDownloadController do
  @moduledoc false
  use DiscoveryApiWeb, :controller

  def fetch_presto(conn, params) do
    fetch_presto(conn, params, get_format(conn))
  end

  def fetch_presto(conn, %{"dataset_id" => dataset_id}, "csv") do
    column_names =
      "describe hive.default.#{dataset_id}"
      |> Prestige.execute()
      |> Prestige.prefetch()
      |> Enum.map(fn [col | _tail] -> col end)

    "select * from #{dataset_id}"
    |> Prestige.execute(catalog: "hive", schema: "default")
    |> map_data_stream_for_csv(column_names)
    |> stream_data(conn, dataset_id)
  end

  def fetch_presto(conn, %{"dataset_id" => dataset_id}, "json") do
    data =
      "select * from #{dataset_id}"
      |> Prestige.execute(catalog: "hive", schema: "default", rows_as_maps: true)
      |> Stream.map(&Jason.encode!/1)
      |> Stream.intersperse(",")

    [["["], data, ["]"]]
    |> Stream.concat()
    |> stream_data(conn, dataset_id)
  end

  defp map_data_stream_for_csv(stream, table_headers) do
    [table_headers]
    |> Stream.concat(stream)
    |> CSV.encode(delimiter: "\n")
  end

  defp stream_data(stream, conn, dataset_id) do
    stream_data(stream, conn, dataset_id, get_format(conn))
  end

  defp stream_data(stream, conn, dataset_id, format) do
    conn =
      conn
      |> put_resp_content_type(MIME.type(format))
      |> put_resp_header("content-disposition", "attachment; filename=#{dataset_id}.#{format}")
      |> send_chunked(200)

    Enum.reduce_while(stream, conn, fn data, conn ->
      case chunk(conn, data) do
        {:ok, conn} -> {:cont, conn}
        {:error, :closed} -> {:halt, conn}
      end
    end)
  end
end

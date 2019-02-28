require Logger

defmodule DiscoveryApiWeb.DatasetQueryController do
  use DiscoveryApiWeb, :controller

  def fetch_presto(conn, %{"dataset_id" => dataset_id}) do
    columnNames =
      Prestige.execute("describe hive.default.#{dataset_id}")
      |> Prestige.prefetch()
      |> Enum.map(fn [col | _tail] -> col end)

    case get_format(conn) do
      "csv" ->
        Prestige.execute("select * from #{dataset_id}", catalog: "hive", schema: "default")
        |> map_data_stream_for_csv(columnNames)
        |> return_csv(conn, dataset_id)

      _ ->
        return_unsupported(conn)
    end
  end

  defp map_data_stream_for_csv(stream, table_headers) do
    Stream.concat([table_headers], stream)
    |> CSV.encode(delimiter: "\n")
  end

  def return_csv(stream, conn, table) do
    conn =
      conn
      |> put_resp_content_type("application/csv")
      |> put_resp_header("content-disposition", "attachment; filename=#{table}.csv")
      |> send_chunked(200)

    Enum.reduce_while(stream, conn, fn data, conn ->
      case chunk(conn, data) do
        {:ok, conn} -> {:cont, conn}
        {:error, :closed} -> {:halt, conn}
      end
    end)
  end

  defp return_unsupported(conn) do
    conn |> resp(415, "")
  end

  def parse_error_reason(reason) when is_binary(reason) do
    case Regex.match?(~r/\bhive\b/i, reason) do
      true -> "Something went wrong with your query."
      _ -> reason
    end
  end

  def parse_error_reason(%{reason: reason}) do
    parse_error_reason(reason)
  end

  def parse_error_reason(_reason) do
    "Your query could not be processed at this time."
  end
end

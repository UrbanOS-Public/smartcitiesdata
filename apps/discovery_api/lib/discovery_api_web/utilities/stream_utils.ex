defmodule DiscoveryApiWeb.Utilities.StreamUtils do
  @moduledoc false
  alias Plug.Conn

  def map_data_stream_for_csv(stream, table_headers) do
    [table_headers]
    |> Stream.concat(stream)
    |> CSV.encode(delimiter: "\n")
  end

  def stream_data(stream, conn, system_name, format) do
    conn =
      conn
      |> Conn.put_resp_content_type(MIME.type(format))
      |> Conn.put_resp_header("content-disposition", "attachment; filename=#{system_name}.#{format}")
      |> Conn.send_chunked(200)

    Enum.reduce_while(stream, conn, fn data, conn ->
      case Conn.chunk(conn, data) do
        {:ok, conn} -> {:cont, conn}
        {:error, :closed} -> {:halt, conn}
      end
    end)
  end
end

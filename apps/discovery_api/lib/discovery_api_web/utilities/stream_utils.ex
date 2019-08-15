defmodule DiscoveryApiWeb.Utilities.StreamUtils do
  @moduledoc """
  Utilities for streaming chunked data and converting a stream to csv
  """
  alias Plug.Conn
  alias DiscoveryApiWeb.Utilities.Hideaway
  require Logger

  def map_data_stream_for_csv(stream, table_headers) do
    [table_headers]
    |> Stream.concat(stream)
    |> CSV.encode(delimiter: "\n")
  end

  # sobelow_skip ["XSS.ContentType"]
  def stream_data(stream, conn, system_name, format) do
    conn =
      conn
      |> Conn.put_resp_content_type(MIME.type(format))
      |> Conn.put_resp_header(
        "content-disposition",
        "attachment; filename=#{system_name}.#{format}"
      )
      |> Conn.send_chunked(200)

    Enum.reduce_while(stream, conn, fn data, conn ->
      case Conn.chunk(conn, execute_if_function(data)) do
        {:ok, conn} ->
          {:cont, conn}

        {:error, :closed} ->
          Hideaway.destroy(conn.assigns[:hideaway])
          {:halt, conn}
      end
    end)
  end

  defp execute_if_function(binary) when is_binary(binary), do: binary
  defp execute_if_function(function) when is_function(function), do: function.()
end

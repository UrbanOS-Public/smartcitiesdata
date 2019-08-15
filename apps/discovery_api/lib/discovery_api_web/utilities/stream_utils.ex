defmodule DiscoveryApiWeb.Utilities.StreamUtils do
  @moduledoc """
  Utilities for streaming chunked data and converting a stream to csv
  """
  alias Plug.Conn
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
      if is_binary(data) do
        case Conn.chunk(conn, data) do
          {:ok, conn} ->
            {:cont, conn}

          {:error, :closed} ->
            Hideaway.destroy(conn.assigns[:hideaway])
            {:halt, conn}
        end
      else
        if is_function(data) do
          case Conn.chunk(conn, execute_if_function(data)) do
            {:ok, conn} ->
              {:cont, conn}

            {:error, :closed} ->
              Hideaway.destroy(conn.assigns[:hideaway])
              {:halt, conn}
          end
        end
      end
    end)
  end

  defp execute_if_function(function) when is_function(function) do
    ["\"bbox\": #{Jason.encode!(function.())}}"] |> IO.inspect(label: "Executed hideaway")
  end
end

defmodule Hideaway do
  use Agent

  def start(initial_value) do
    Agent.start(fn -> initial_value end)
  end

  def stash(pid, new_value) do
    Agent.update(pid, fn _ ->
      new_value |> IO.inspect(label: "Hideaway stashing:")
    end)

    new_value
  end

  def retrieve(pid) do
    Agent.get(pid, fn state ->
      state |> IO.inspect(label: "Hideaway retrieving:")
    end)
  end

  def destroy(pid) do
    Process.exit(pid, :done)
  end
end

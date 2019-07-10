defmodule DiscoveryApiWeb.Plugs.Acceptor do
  @moduledoc """
  This plug is used as an unopinionated alternative to the `:accept` plug provided by Phoenix. It parses out all possible extensions provided by the first MIME type provided in the accept header. These are stored as a list in the phoenix_format assign in the connection.
  """
  require Logger
  import Plug.Conn

  def init(default), do: default

  def call(conn, _) do
    conn.params
    |> Map.get("_format", extract_accept_header(conn))
    |> List.wrap()
    |> set_format(conn)
  end

  defp set_format(format, conn) do
    put_private(conn, :phoenix_format, format)
  end

  defp extract_accept_header(conn) do
    case List.first(get_req_header(conn, "accept")) do
      nil ->
        []

      header ->
        header
        |> String.split(",", trim: true)
        |> List.first()
        |> MIME.extensions()
    end
  end
end

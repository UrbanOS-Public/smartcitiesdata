defmodule DiscoveryApiWeb.Plugs.Acceptor do
  @moduledoc false
  require Logger
  import Plug.Conn

  def init(default), do: default

  def call(conn, _) do
    format =
      conn
      |> get_req_header("accept")
      |> hd()
      |> String.split(",", trim: true)
      |> hd()
      |> MIME.extensions()

    conn
    |> assign(:accepted_extensions, format)
  end
end

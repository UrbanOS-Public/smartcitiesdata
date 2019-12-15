defmodule DiscoveryStreamsWeb.NodelistController do
  use DiscoveryStreamsWeb, :controller

  def index(conn, _params) do
    text(conn, "#{inspect([Node.self() | Node.list()])}")
  end
end

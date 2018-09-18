defmodule CotaStreamingConsumerWeb.NodelistController do
  use CotaStreamingConsumerWeb, :controller

  def index(conn, _params) do
    text(conn, "#{inspect([Node.self() | Node.list()])}")
  end
end

defmodule CotaStreamingConsumerWeb.HealthCheckController do
  use CotaStreamingConsumerWeb, :controller

  def index(conn, _params) do
    text(conn, "Up")
  end
end

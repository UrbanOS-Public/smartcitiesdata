defmodule CotaStreamingConsumerWeb.Router do
  use CotaStreamingConsumerWeb, :router

  pipeline :logger do
    plug(Plug.Logger)
  end

  scope "/socket/nodelist", CotaStreamingConsumerWeb do
    pipe_through(:logger)
    get("/", NodelistController, :index)
  end

  scope "/socket/healthcheck", CotaStreamingConsumerWeb do
    get("/", HealthCheckController, :index)
  end
end

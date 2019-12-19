defmodule DiscoveryStreamsWeb.Router do
  use DiscoveryStreamsWeb, :router

  pipeline :logger do
    plug(Plug.Logger)
  end

  scope "/socket/nodelist", DiscoveryStreamsWeb do
    pipe_through(:logger)
    get("/", NodelistController, :index)
  end

  scope "/socket/healthcheck", DiscoveryStreamsWeb do
    get("/", HealthCheckController, :index)
  end
end

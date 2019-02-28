use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

config :discovery_api,
  docker: %{
    version: "2",
    services: %{
      redis: %{
        image: "redis",
        ports: ["6379:6379"]
      }
    }
  },
  docker_wait_for: "Ready to accept connections"

config :redix,
  host: host

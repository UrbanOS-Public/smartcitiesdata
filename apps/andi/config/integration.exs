use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "localhost"
    defined -> defined
  end

System.put_env("HOST", host)

config :andi,
  divo: "./docker-compose.yaml",
  divo_wait: [dwell: 700, max_tries: 50]

config :smart_city_registry,
  redis: [host: host]

config :paddle, Paddle,
  host: host,
  base: "dc=example,dc=org",
  timeout: 3000

use Mix.Config

config :telemetry_event,
  metrics_port: Enum.random(1_000..9_999)
                |> IO.inspect(label: "Telemetry Prometheus Metrics is hosted on Port No")

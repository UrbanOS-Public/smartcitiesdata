use Mix.Config

config :telemetry_event,
  metrics_port: Enum.random(1_000..9_999)

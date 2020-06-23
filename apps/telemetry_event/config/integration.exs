use Mix.Config

config :telemetry_event,
  metrics_port: Enum.random(1_000..9_999),
  metrics_options: [
    metric_name: "events_handled.count",
    tags: [:app, :author, :dataset_id, :event_type]
  ]

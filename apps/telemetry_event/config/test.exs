use Mix.Config

config :telemetry_event,
  metrics_port: Enum.random(1_000..9_999),
  metrics_options: [
    metric_name: "any_events_handled.count",
    tags: [:any_app, :any_author, :any_dataset_id, :any_event_type]
  ]

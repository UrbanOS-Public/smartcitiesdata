use Mix.Config

config :telemetry_event,
  app_name: "any_telemetry_app",
  metrics_options: [
    [
      metric_name: "any_events_handled.count",
      tags: [:any_app, :any_author, :any_dataset_id, :any_event_type]
    ],
    [
      metric_name: "any_dead_letters_handled.count",
      tags: [:any_dataset_id, :any_reason]
    ]
  ]

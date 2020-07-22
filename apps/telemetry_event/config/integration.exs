use Mix.Config

config :telemetry_event,
  metrics_options: [
    [
      metric_name: "events_handled.count",
      tags: [:app, :author, :dataset_id, :event_type]
    ],
    [
      metric_name: "dead_letters_handled.count",
      tags: [:dataset_id, :reason]
    ]
  ]

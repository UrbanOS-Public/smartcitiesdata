use Mix.Config

config :telemetry_event,
  init_server: false,
  metrics_options: [
    [
      metric_name: "dead_letters_handled.count",
      tags: [:dataset_id, :reason],
      metric_type: :counter
    ],
    [
      metric_name: "dataset_compaction_duration_total.duration",
      tags: [:app, :system_name],
      metric_type: :sum
    ]
  ]

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
    ],
    [
      metric_name: "file_conversion_success.gauge",
      tags: [:app, :dataset_id, :file, :start],
      metric_type: :last_value
    ],
    [
      metric_name: "file_conversion_duration.gauge",
      tags: [:app, :dataset_id, :file, :start],
      metric_type: :last_value
    ]
  ]

import Config

config :telemetry_event,
  init_server: false,
  add_poller: false,
  add_metrics: [:dead_letters_handled_count, :phoenix_endpoint_stop_duration, :dataset_total_count],
  metrics_options: [
    [
      metric_name: "dataset_compaction_duration_total.duration",
      tags: [:app, :system_name],
      metric_type: :last_value
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
    ],
    [
      metric_name: "dataset_record_total.count",
      tags: [:system_name],
      metric_type: :last_value
    ],
    [
      metric_name: "dataset_info.gauge",
      tags: [:dataset_id, :dataset_title, :system_name, :source_type, :org_name],
      metric_type: :last_value
    ]
  ]

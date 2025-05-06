import Config

config :telemetry_event,
  init_server: false,
  add_poller: false,
  add_metrics: [:dead_letters_handled_count, :phoenix_endpoint_stop_duration, :dataset_total_count],
  metrics_options: [
    [
      metric_name: "any_events_handled.count",
      tags: [:any_app, :any_author, :any_dataset_id, :any_event_type],
      metric_type: :counter
    ],
    [
      metric_name: "any_dead_letters_handled.count",
      tags: [:any_dataset_id, :any_reason],
      metric_type: :counter
    ],
    [
      metric_name: "any_dataset_compaction_duration_total.duration",
      tags: [:any_app, :any_system_name],
      metric_type: :last_value
    ],
    [
      metric_name: "any_file_conversion_success.gauge",
      tags: [:any_app, :any_dataset_id, :any_file, :any_start],
      metric_type: :last_value
    ],
    [
      metric_name: "any_file_conversion_duration.gauge",
      tags: [:any_app, :any_dataset_id, :any_file, :any_start],
      metric_type: :last_value
    ],
    [
      metric_name: "any_dataset_record_total.count",
      tags: [:any_system_name],
      metric_type: :last_value
    ],
    [
      metric_name: "any_dataset_info.gauge",
      tags: [:any_dataset_id, :any_dataset_title, :any_system_name, :any_source_type, :any_org_name],
      metric_type: :last_value
    ]
  ]

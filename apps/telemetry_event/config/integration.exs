use Mix.Config

config :telemetry_event,
  init_server: false,
  metrics_options: [
    [
      metric_type_and_name: [:counter, :events_handled, :count],
      tags: [:app, :author, :dataset_id, :event_type]
    ],
    [
      metric_type_and_name: [:counter, :dead_letters_handled, :count],
      tags: [:dataset_id, :reason]
    ],
    [
      metric_type_and_name: [:sum, :dataset_compaction_duration_total, :duration],
      tags: [:app, :system_name]
    ]
  ]

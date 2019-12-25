use Mix.Config

config :logger, level: :warn

config :estuary,
  topic_reader: MockReader,
  table_writer: MockTable,
  endpoints: [localhost: 9092],
  retry_count: 5,
  retry_initial_delay: 10,
  topic_subscriber_config: [
    begin_offset: :earliest,
    offset_reset_policy: :reset_to_earliest,
    max_bytes: 1_000_000,
    min_bytes: 500_000,
    max_wait_time: 10_000
  ]

# config :prestige, 
#   base_url: "http://127.0.0.1:8080"
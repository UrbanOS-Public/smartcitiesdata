use Mix.Config

config :estuary,
  elsa_endpoint: nil

config :logger, level: :warn

config :estuary,
<<<<<<< HEAD
  topic_reader: MockReader,
=======
  data_reader: MockReader,
  topic_writer: MockTopic,
>>>>>>> adding config for event reading
  table_writer: MockTable,
  retry_count: 5,
  retry_initial_delay: 10,
  topic_subscriber_config: [
    begin_offset: :earliest,
    offset_reset_policy: :reset_to_earliest,
    max_bytes: 1_000_000,
    min_bytes: 500_000,
    max_wait_time: 10_000
  ]

import Config

host = "localhost"

endpoint = [{to_charlist(host), 9092}]

config :flair,
  window_unit: :second,
  window_length: 1,
  message_timeout: 5 * 60 * 1_000,
  task_timeout: 5 * 60 * 1_000,
  table_name_timing: "operational_stats",
  divo: [
    {DivoKafka,
     [
       create_topics: "persisted:1:1,dead-letters:1:1",
       outside_host: host,
       kafka_image_version: "2.12-2.1.1"
     ]},
    Flair.DivoPresto
  ],
  divo_wait: [dwell: 1000, max_tries: 60],
  elsa_brokers: endpoint,
  message_processing_cadence: 5_000,
  data_topic: "streaming-persisted",
  topic_subscriber_config: [
    begin_offset: :earliest,
    offset_reset_policy: :reset_to_earliest,
    max_bytes: 1_000_000,
    min_bytes: 0,
    max_wait_time: 10_000
  ]

config :prestige, :session_opts,
  url: "http://#{host}:8080",
  catalog: "hive",
  schema: "default",
  user: "foobar"

config :smart_city_test,
  endpoint: endpoint

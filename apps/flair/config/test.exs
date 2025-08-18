import Config

config :flair,
  table_writer: MockTableWriter,
  topic_reader: MockTopicReader,
  producer_module: MockProducer,
  window_unit: :second,
  window_length: 1,
  message_timeout: 50,
  task_timeout: 50

config :prestige, :session_opts, url: "http://127.0.0.1:8080"

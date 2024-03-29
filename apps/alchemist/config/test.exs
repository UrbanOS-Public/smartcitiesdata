use Mix.Config

config :alchemist,
  elsa_brokers: [localhost: 9092],
  retry_count: 5,
  retry_initial_delay: 10,
  input_topic_prefix: "raw",
  output_topic_prefix: "unit",
  broadway_producer_module: Fake.Producer

config :alchemist, :brook,
  handlers: [Alchemist.Event.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ],
  hosted_file_bucket: "hosted-dataset-files"

config :logger,
  backends: [:console],
  compile_time_purge_matching: [[lower_level_than: :debug]]

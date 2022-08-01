import Config

config :valkyrie,
  elsa_brokers: [localhost: 9092],
  retry_count: 5,
  retry_initial_delay: 10,
  input_topic_prefix: "raw",
  output_topic_prefix: "unit",
  broadway_producer_module: Fake.Producer

config :valkyrie, :brook,
  handlers: [Valkyrie.Event.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ],
  hosted_file_bucket: "hosted-dataset-files"

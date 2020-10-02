use Mix.Config

config :valkyrie,
  endpoints: [localhost: 9092],
  retry_count: 5,
  retry_initial_delay: 10

config :valkyrie, :brook,
  instance: :valkyrie,
  handlers: [Valkyrie.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ],
  hosted_file_bucket: "hosted-dataset-files"

config :dlq, Dlq.Application, init?: false

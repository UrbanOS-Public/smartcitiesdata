use Mix.Config

config :logger, :level, :warn

config :forklift,
  retry_count: 5,
  retry_initial_delay: 10,
  # To ensure that MessageWriter never starts while testing
  message_processing_cadence: 1_000_000_000,
  cache_processing_batch_size: 1_000,
  user: "foobar"

config :forklift, :brook,
  handlers: [Forklift.Event.Handler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: [
      namespace: "forklift:view"
    ]
  ]

config :prestige,
  base_url: "https://kdp-kubernetes-data-platform-presto.kdp:8080",
  headers: [
    user: "foobar"
  ]

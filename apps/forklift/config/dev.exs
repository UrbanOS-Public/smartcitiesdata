use Mix.Config

config :forklift,
  message_processing_cadence: 15_000,
  user: "forklift"

config :prestige, base_url: "http://127.0.0.1:8080"

config :redix,
  host: "localhost"

config :husky,
  pre_commit: "./scripts/git_pre_commit_hook.sh"

config :forklift, :brook,
  handlers: [Forklift.Event.Handler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: [
      namespace: "forklift:view"
    ]
  ]

config :libcluster,
  topologies: [
    forklift_cluster: [
      strategy: Elixir.Cluster.Strategy.Epmd,
      config: [
        hosts: [:"a@127.0.0.1", :"b@127.0.0.1"]
      ]
    ]
  ]

use Mix.Config

config :logger,
  level: :info

config :libcluster,
  topologies: [
    valkyrie_cluster: [
      strategy: Elixir.Cluster.Strategy.Epmd,
      config: [
        hosts: [:"a@127.0.0.1", :"b@127.0.0.1"]
      ]
    ]
  ]

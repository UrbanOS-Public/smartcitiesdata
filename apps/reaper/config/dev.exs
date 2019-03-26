use Mix.Config

config :libcluster,
  topologies: [
    sculler_cluster: [
      strategy: Elixir.Cluster.Strategy.Epmd,
      config: [
        hosts: [:"a@127.0.0.1", :"b@127.0.0.1"]
      ]
    ]
  ]

config :redix,
  host: "localhost"

System.put_env("HOST", "localhost")

config :reaper,
  divo: "./docker-compose.yaml",
  divo_wait: [dwell: 700, max_tries: 50]

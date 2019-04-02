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
  divo: [
    {DivoKafka, [create_topics: "streaming-raw:1:1"]},
    DivoRedis
  ],
  divo_wait: [dwell: 700, max_tries: 50]

use Mix.Config

kafka_brokers = System.get_env("KAFKA_BROKERS")

if kafka_brokers do
  endpoints =
    kafka_brokers
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn entry -> String.split(entry, ":") end)
    |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

  config :kaffe,
    consumer: [
      endpoints: endpoints
    ]
end

if System.get_env("RUN_IN_KUBERNETES") do
  config :libcluster,
    topologies: [
      forklift_cluster: [
        strategy: Elixir.Cluster.Strategy.Kubernetes,
        config: [
          mode: :dns,
          kubernetes_node_basename: "forklift",
          kubernetes_selector: "app.kubernetes.io/name=forklift",
          polling_interval: 10_000
        ]
      ]
    ]
end

config :prestige, base_url: System.get_env("PRESTO_URL")

if System.get_env("LOCALSTACK") do
# For working with release builds locally
  config :ex_aws,
    access_key_id: "x",
    secret_access_key: "y",
    debug_requests: true

  config :ex_aws, :monitoring,
    scheme: "http",
    host: "aws",
    port: 4582

  config :ex_aws, :retries,
    max_attempts: 30,
    base_backoff_in_ms: 1_000,
    max_backoff_in_ms: 1_000
end

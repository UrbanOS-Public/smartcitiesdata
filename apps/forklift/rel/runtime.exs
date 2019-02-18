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

# if System.get_env("RUN_IN_KUBERNETES") do
#   config :libcluster,
#     topologies: [
#       forklift_cluster: [
#         strategy: Elixir.Cluster.Strategy.Kubernetes,
#         config: [
#           mode: :dns,
#           kubernetes_node_basename: "forklift",
#           kubernetes_selector: "app.kubernetes.io/name=forklift",
#           polling_interval: 10_000
#         ]
#       ]
#     ]
# end

config :prestige, base_url: System.get_env("PRESTO_URL")

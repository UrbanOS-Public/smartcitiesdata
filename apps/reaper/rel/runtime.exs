use Mix.Config

required_envars = [
  "REDIS_HOST",
  "KAFKA_BROKERS",
  "OUTPUT_TOPIC_PREFIX",
  "DLQ_TOPIC",
  "SECRETS_ENDPOINT",
  "HOSTED_FILE_BUCKET"
]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

kafka_brokers = System.get_env("KAFKA_BROKERS")
redis_host = System.get_env("REDIS_HOST")

endpoints =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

if System.get_env("RUN_IN_KUBERNETES") do
  config :libcluster,
    topologies: [
      reaper_cluster: [
        strategy: Elixir.Cluster.Strategy.Kubernetes,
        config: [
          mode: :dns,
          kubernetes_node_basename: "reaper",
          kubernetes_selector: "app.kubernetes.io/name=reaper",
          polling_interval: 10_000
        ]
      ]
    ]
end

config :reaper,
  secrets_endpoint: System.get_env("SECRETS_ENDPOINT"),
  elsa_brokers: endpoints,
  output_topic_prefix: System.get_env("OUTPUT_TOPIC_PREFIX"),
  download_dir: System.get_env("DOWNLOAD_DIR") || "/downloads/",
  hosted_file_bucket: System.get_env("HOSTED_FILE_BUCKET") || "hosted-dataset-files"

config :smart_city_registry,
  redis: [
    host: redis_host
  ]

config :redix,
  host: redis_host

config :yeet,
  endpoint: endpoints,
  topic: System.get_env("DLQ_TOPIC")

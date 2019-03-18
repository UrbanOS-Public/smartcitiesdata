use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

System.put_env("HOST", host)

endpoints = [{to_char_list(host), 9092}]

config :discovery_api, DiscoveryApiWeb.Endpoint,
  url: [host: "discoveryapi.integrationtests.com", port: {:system, "PORT"}]

config :redix,
  host: host

config :kaffe,
  producer: [
    endpoints: endpoints,
    topics: ["dataset-registry"],
    max_retries: 30,
    retry_backoff_ms: 500
  ],
  consumer: [
    endpoints: endpoints,
    topics: ["dataset-registry"],
    consumer_group: "discovery-dataset-consumer",
    message_handler: DiscoveryApi.Data.DatasetEventListener,
    rebalance_delay_ms: 10_000,
    start_with_earliest_message: true
  ]

config :phoenix,
  serve_endpoints: true,
  persistent: true

config :discovery_api,
  divo: "test/integration/docker-compose.yaml",
  divo_wait: [dwell: 700, max_tries: 50]

config :ex_json_schema,
       :remote_schema_resolver,
       fn url -> URLResolver.resolve_url(url) end

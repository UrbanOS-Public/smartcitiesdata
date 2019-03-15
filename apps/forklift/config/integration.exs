use Mix.Config

config :forklift,
  timeout: 6,
  batch_size: 1

config :kaffe,
  producer: [
    endpoints: [localhost: 9094],
    topics: ["streaming-transformed"],
    max_retries: 30,
    retry_backoff_ms: 500
  ],
  consumer: [
    endpoints: [localhost: 9094]
  ]

config :prestige,
  base_url: "http://localhost:8080",
  headers: [
    user: "foobar"
  ]

config(:forklift, divo: "docker-compose.yml", divo_wait: [dwell: 1000, max_tries: 50])

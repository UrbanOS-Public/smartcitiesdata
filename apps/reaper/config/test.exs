use Mix.Config

config :logger,
  level: :info

config :phoenix, :json_library, Jason

config :yeet,
  topic: "dead-letters"

config :kaffe,
  producer: [
    endpoints: [],
    topics: []
  ]

config :reaper,
  produce_retries: 2,
  produce_timeout: 10,
  secrets_endpoint: "http://vault:8200"

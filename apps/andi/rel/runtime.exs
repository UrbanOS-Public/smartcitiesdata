use Mix.Config

config :kaffe,
  producer: [
    endpoints: [{String.to_atom(System.get_env("KAFKA_BROKERS")), 9092}]
  ]

config :smart_city_registry,
  redis: [
    host: System.get_env("REDIS_HOST")
  ]

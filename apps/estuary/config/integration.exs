use Mix.Config

config :estuary,
  divo: [
    {DivoKafka, [outside_host: "localhost"]}
  ],
  divo_wait: [dwell: 700, max_tries: 50]

config :logger, level: :debug

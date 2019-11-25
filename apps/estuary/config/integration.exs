use Mix.Config

config :estuary,
  divo: [
    {DivoKafka, [create_topics: "topic-one:1:3,topic-two:1:1", outside_host: "localhost"]}
  ],
  divo_wait: [dwell: 700, max_tries: 50]

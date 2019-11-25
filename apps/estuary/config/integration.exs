use Mix.Config

config :estuary,
  divo: [
    {DivoKafka, [create_topics: "topic1:1:1,topic2:1:1:compact", outside_host: "localhost"]}
  ],
  divo_wait: [dwell: 700, max_tries: 50]

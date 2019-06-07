use Mix.Config

host = "127.0.0.1"

config :discovery_streams,
  divo: [
    {DivoKafka, [create_topics: "cota-vehicle-positions:1:1,shuttle-positions:1:1", outside_host: host]}
  ],
  divo_wait: [dwell: 700, max_tries: 50]

config :kaffe,
  consumer: [
    endpoints: [{String.to_atom(host), 9092}],
    topics: [],
    consumer_group: "discovery-streams",
    message_handler: DiscoveryStreams.MessageHandler,
    offset_reset_policy: :reset_to_latest
  ]

config :discovery_streams, topic_subscriber_interval: 1_000

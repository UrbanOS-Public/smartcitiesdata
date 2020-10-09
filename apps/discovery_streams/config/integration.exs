use Mix.Config

host = "127.0.0.1"
endpoints = [{String.to_atom(host), 9092}]

config :discovery_streams,
  divo: [
    {DivoKafka, [create_topics: "event-stream:1:1", outside_host: host, kafka_image_version: "2.12-2.1.1"]},
    {DivoRedis, []}
  ],
  divo_wait: [dwell: 700, max_tries: 50]

config :discovery_streams, endpoints: endpoints

config :discovery_streams, topic_subscriber_interval: 1_000

config :discovery_streams, :brook,
  instance: :discovery_streams,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoints,
      topic: "event-stream",
      group: "discovery_streams-events",
      consumer_config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [DiscoveryStreams.Event.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [
      redix_args: [host: host],
      namespace: "discovery_streams:view"
    ]
  ]

config :phoenix, serve_endpoints: true

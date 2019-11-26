use Mix.Config

config :estuary,
  divo: [
    {DivoKafka, [create_topics: "event-stream-integration:1:1", outside_host: "localhost"]}
  ],
  divo_wait: [dwell: 700, max_tries: 50],
  elsa_endpoint: [localhost: 9092],
  event_stream_topic: "event-stream-integration"

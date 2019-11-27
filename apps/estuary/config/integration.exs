use Mix.Config

config :estuary,
  divo: [
    {DivoKafka, [outside_host: "localhost"]}
  ],
  divo_wait: [dwell: 700, max_tries: 50],
  elsa_endpoint: [localhost: 9092],
  event_stream_topic: "event-stream-integration"

use Mix.Config

config :dead_letter,
  divo: [
    {DivoKafka, [create_topics: "dead-letters:1:1", auto_topic: false]}
  ],
  divo_wait: [dwell: 700, max_tries: 50],
  driver: [
    module: DeadLetter.Carrier.Kafka,
    init_args: [
      endpoints: [localhost: 9092],
      topic: "dead-letters"
    ]
  ]

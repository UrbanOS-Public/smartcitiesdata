import Config

config :dead_letter,
  divo: [
    {DivoKafka, [create_topics: "dead-letters:1:1", auto_topic: false, kafka_image_version: "2.12-2.1.1"]}
  ],
  divo_wait: [dwell: 700, max_tries: 50],
  driver: [
    module: DeadLetter.Carrier.Kafka,
    init_args: [
      endpoints: [localhost: 9092],
      topic: "dead-letters"
    ]
  ]

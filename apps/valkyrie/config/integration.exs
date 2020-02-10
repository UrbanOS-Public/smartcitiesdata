use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

redix_args = [host: host]

endpoints = [{String.to_atom(host), 9092}]

config :logger,
  level: :info

config :valkyrie,
  elsa_brokers: endpoints,
  input_topic_prefix: "raw",
  output_topic_prefix: "transformed",
  divo: [
    {DivoKafka,
     [
       create_topics: "raw:1:1,validated:1:1,dead-letters:1:1, event-stream:1:1",
       outside_host: host,
       auto_topic: false,
       kafka_image_version: "2.12-2.0.1"
     ]},
    DivoRedis
  ],
  divo_wait: [dwell: 700, max_tries: 50],
  retry_count: 5,
  retry_initial_delay: 1500

config :valkyrie, :brook,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoints,
      topic: "event-stream",
      group: "valkyrie-events",
      consumer_config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [Valkyrie.DatasetHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [
      redix_args: redix_args,
      namespace: "valkyrie:view"
    ]
  ]

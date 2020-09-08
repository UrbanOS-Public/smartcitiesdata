use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "localhost"
    defined -> defined
  end

redix_args = [host: host]
endpoint = [{host, 9092}]

config :andi,
  divo: [
    {DivoKafka, [create_topics: "event-stream:1:1", outside_host: host, kafka_image_version: "2.12-2.1.1"]},
    {DivoRedis, []},
    {Andi.DivoPostgres, []}
  ],
  divo_wait: [dwell: 700, max_tries: 50],
  kafka_broker: endpoint,
  dead_letter_topic: "dead-letters"

config :andi, Andi.Repo,
  database: "andi",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  port: "5456"

config :andi, AndiWeb.Endpoint,
  http: [port: 4000],
  server: true,
  check_origin: false

config :andi, :brook,
  instance: :andi,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoint,
      topic: "event-stream",
      group: "andi-event-stream",
      consumer_config: [
        begin_offset: :earliest,
        offset_reset_policy: :reset_to_earliest
      ]
    ]
  ],
  handlers: [Andi.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [redix_args: redix_args, namespace: "andi:view"]
  ]

config :andi, AndiWeb.Endpoint,
  pubsub: [name: AndiWeb.PubSub, adapter: Phoenix.PubSub.PG2],
  code_reloader: true,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ],
  reloadable_apps: [:andi],
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/andi_web/controllers/.*(ex)$},
      ~r{lib/andi_web/live/.*(ex)$},
      ~r{lib/andi_web/views/.*(ex)$},
      ~r{lib/andi_web/templates/.*(eex)$}
    ]
  ],
  live_view: [
    signing_salt: "SUPER VERY TOP SECRET!!!"
  ]

config :andi, :elsa,
  endpoints: endpoint,
  name: :andi_elsa,
  connection: :andi_reader,
  group_consumer: [
    name: "andi_reader",
    group: "andi_reader_group",
    topics: ["dead-letters"],
    handler: Andi.MessageHandler,
    handler_init_args: [],
    config: [
      begin_offset: 0,
      offset_reset_policy: :latest,
      prefetch_count: 0,
      prefetch_bytes: 2_097_152
    ]
  ]

defmodule Andi.DivoPostgres do
  @moduledoc """
  Defines a postgres stack compatible with divo
  for building a docker-compose file.
  """

  def gen_stack(_envar) do
    %{
      postgres: %{
        logging: %{driver: "none"},
        image: "postgres:9.6.16",
        ports: ["5456:5432"]
      }
    }
  end
end

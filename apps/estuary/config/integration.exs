import Config

endpoints = [localhost: 9092]

config :prestige, :session_opts, url: "http://127.0.0.1:8080"

config :estuary,
  endpoints: endpoints,
  divo: "docker-compose.yml",
  divo_wait: [dwell: 1000, max_tries: 120],
  topic_reader: Pipeline.Reader.TopicReader,
  table_writer: Pipeline.Writer.TableWriter,
  topic: "event-stream",
  topic_subscriber_config: [
    begin_offset: :earliest,
    offset_reset_policy: :reset_to_earliest,
    max_bytes: 1_000_000,
    min_bytes: 500_000,
    max_wait_time: 30_000
  ]

config :logger, level: :warn

config :estuary, EstuaryWeb.Endpoint,
  http: [port: 4010],
  server: true,
  check_origin: false

config :estuary, EstuaryWeb.Endpoint,
  code_reloader: true,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch",
      "--watch-options-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ],
  reloadable_apps: [:estuary],
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/estuary_web/controllers/.*(ex)$},
      ~r{lib/estuary_web/live/.*(ex)$},
      ~r{lib/estuary_web/views/.*(ex)$},
      ~r{lib/estuary_web/templates/.*(eex)$}
    ]
  ],
  live_view: [
    signing_salt: "SUPER VERY TOP SECRET!!!"
  ]

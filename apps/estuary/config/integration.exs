use Mix.Config

endpoints = [localhost: 9092]

config :prestige,
  base_url: "http://127.0.0.1:8080"

config :estuary,
  endpoints: endpoints,
  divo: "docker-compose.yml",
  divo_wait: [dwell: 1000, max_tries: 120],
  topic_reader: Pipeline.Reader.TopicReader,
  table_writer: Pipeline.Writer.TableWriter,
  topic: "event-stream"

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
      "--watch-stdin",
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

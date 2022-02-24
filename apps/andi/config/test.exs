use Mix.Config

config :andi, AndiWeb.Endpoint,
  http: [port: 4002],
  server: false,
  live_view: [
    signing_salt: "CHANGEME?"
  ]

config :logger, level: :warn

config :andi, :brook,
  instance: :andi,
  driver: [
    module: Brook.Driver.Default,
    init_arg: []
  ],
  handlers: [Andi.Event.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ]

config :andi,
  dead_letter_topic: "dead-letters",
  hsts_enabled: false,
  access_level: :private

config :andi, AndiWeb.Auth.TokenHandler,
  issuer: "https://project-hercules.us.auth0.com/",
  allowed_algos: ["RS256"],
  verify_issuer: false,
  allowed_drift: 3_000_000_000_000

config :andi, Guardian.DB, repo: Andi.Repo

System.put_env("AWS_ACCESS_KEY_ID", "testing_access_key")
System.put_env("AWS_ACCESS_KEY_SECRET", "testing_secret_key")

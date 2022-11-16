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
  issuer: "https://urbanos-dev.us.auth0.com/",
  allowed_algos: ["RS256"],
  verify_issuer: false,
  allowed_drift: 3_000_000_000_000

config :andi, Guardian.DB, repo: Andi.Repo

System.put_env("AWS_ACCESS_KEY_ID", "minioadmin")
System.put_env("AWS_ACCESS_KEY_SECRET", "minioadmin")
System.put_env("ANDI_LOGO_URL", "/images/UrbanOS.svg")
System.put_env("ANDI_HEADER_TEXT", "Data Submission Tool")
System.put_env("ANDI_PRIMARY_COLOR", "#1170C8")
System.put_env("ANDI_FOOTER_LEFT_SIDE_TEXT", "Some Left Side Text")
System.put_env("ANDI_FOOTER_LEFT_SIDE_LINK", "https://www.example.com")

System.put_env(
  "ANDI_FOOTER_RIGHT_LINKS",
  "[{\"linkText\":\"Example 1\", \"url\":\"https://www.example.com\"}, {\"linkText\":\"Example 2\", \"url\":\"https://www.google.com\"}]"
)

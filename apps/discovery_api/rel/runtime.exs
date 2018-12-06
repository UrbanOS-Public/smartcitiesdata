use Mix.Config

config :discovery_api,
  data_lake_url: System.get_env("DATA_LAKE_URL"),
  data_lake_auth_string: System.get_env("DATA_LAKE_AUTH_STRING")

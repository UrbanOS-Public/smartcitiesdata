use Mix.Config

config :discovery_api,
  data_lake_url: System.get_env("DATA_LAKE_URL"),
  data_lake_auth_string: System.get_env("DATA_LAKE_AUTH_STRING"),
  thrive_address: System.get_env("HIVE_ADDRESS"),
  thrive_port: String.to_integer(System.get_env("HIVE_PORT")),
  thrive_username: System.get_env("HIVE_USERNAME"),
  thrive_password: System.get_env("HIVE_PASSWORD")

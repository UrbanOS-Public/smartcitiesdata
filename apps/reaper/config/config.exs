import Config

config :logger,
  level: :info

config :reaper,
  env: Mix.env(),
  produce_retries: 10,
  produce_timeout: 100

import_config "#{config_env()}.exs"

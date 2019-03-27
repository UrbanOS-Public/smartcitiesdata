use Mix.Config

import_config "#{Mix.env()}.exs"

config :phoenix, :json_library, Jason

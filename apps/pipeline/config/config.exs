import Config
if config_env() == :integration, do: import_config("integration.exs")

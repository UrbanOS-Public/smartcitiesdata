import Config
if config_env() == :integration, do: import_config("integration.exs")
if config_env() == :test, do: import_config("test.exs")

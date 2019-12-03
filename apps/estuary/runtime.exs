use Mix.Config

required_envars = [
  "PRESTO_USER",
  "PRESTO_URL"
]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

config :prestige,
  base_url: System.get_env("PRESTO_URL"),
  headers: [user: System.get_env("PRESTO_USER")]

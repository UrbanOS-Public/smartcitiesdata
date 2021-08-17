use Mix.Config

get_redix_args = fn host, password ->
  [host: host, password: password]
  |> Enum.filter(fn
    {_, nil} -> false
    {_, ""} -> false
    _ -> true
  end)
end

kafka_brokers = System.get_env("KAFKA_BROKERS")

endpoint =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

config :raptor, RaptorWeb.Endpoint,
  url: [
    scheme: "https",
    host: System.get_env("HOST"),
    port: 443
  ],
  http: [protocol_options: [
    # These values may be superseded by network level timeouts such as a load balancer.
    inactivity_timeout: 4_000_000,
    idle_timeout: 4_000_000
    ]
  ]

config :raptor,

config :raptor, Raptor.Repo,
  database: System.get_env("POSTGRES_DBNAME"),
  username: System.get_env("POSTGRES_USER"),
  password: System.get_env("POSTGRES_PASSWORD"),
  hostname: System.get_env("POSTGRES_HOST"),
  port: System.get_env("POSTGRES_PORT"),
  ssl: true,
  ssl_opts: [
    verify: :verify_peer,
    versions: [:"tlsv1.2"],
    cacertfile: System.get_env("CA_CERTFILE_PATH"),
    server_name_indication: String.to_charlist(System.get_env("POSTGRES_HOST", "")),
    verify_fun:
    {&:ssl_verify_hostname.verify_fun/3,
     [check_hostname: String.to_charlist(System.get_env("POSTGRES_HOST", ""))]}
  ]

required_envars = ["REDIS_HOST", "ALLOWED_ORIGINS", "PRESIGN_KEY"]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

config :raptor, :brook,
  instance: :raptor,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoint,
      topic: "event-stream",
      group: "raptor-event-stream",
      config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [Raptor.Event.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [
      redix_args: redix_args,
      namespace: "raptor:view",
      event_limits: %{
        "user:organization:associate" => 100,
        "user:organization:disassociate" => 100
      }
    ]
  ]
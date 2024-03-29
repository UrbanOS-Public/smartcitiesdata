use Mix.Config

get_redix_args = fn host, password ->
  [host: host, password: password]
  |> Enum.filter(fn
    {_, nil} -> false
    {_, ""} -> false
    _ -> true
  end)
end

redix_args = get_redix_args.(System.get_env("REDIS_HOST"), System.get_env("REDIS_PASSWORD"))

kafka_brokers = System.get_env("KAFKA_BROKERS")

endpoint =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

config :template, TemplateWeb.Endpoint,
  url: [
    scheme: "https",
    host: System.get_env("HOST"),
    port: 443
  ],
  http: [
    protocol_options: [
      # These values may be superseded by network level timeouts such as a load balancer.
      inactivity_timeout: 4_000_000,
      idle_timeout: 4_000_000
    ]
  ]

required_envars = ["REDIS_HOST"]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

config :template, :brook,
  instance: :template,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoint,
      topic: "event-stream",
      group: "template-event-stream",
      config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [Template.Event.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [
      redix_args: redix_args,
      namespace: "template:view",
      event_limits: %{
        "dataset:update" => 100,
        "organization:update" => 100,
        "user:organization:associate" => 100,
        "user:organization:disassociate" => 100
      }
    ]
  ]

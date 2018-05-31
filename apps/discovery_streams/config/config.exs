use Mix.Config

config :cota_streaming_consumer, CotaStreamingConsumerWeb.Endpoint,
  http: [port: 4000],
  secret_key_base: "This is a test key",
  render_errors: [view: CotaStreamingConsumerWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: CotaStreamingConsumer.PubSub, adapter: Phoenix.PubSub.PG2]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :cota_streaming_consumer, :children, [
  Supervisor.Spec.supervisor(Kaffe.GroupMemberSupervisor, [])
]

import_config "#{Mix.env()}.exs"

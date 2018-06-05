defmodule CotaStreamingConsumer.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(CotaStreamingConsumerWeb.Endpoint, []) |
      Application.get_env(:cota_streaming_consumer, :children, [])
    ]

    opts = [strategy: :one_for_one, name: CotaStreamingConsumer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    CotaStreamingConsumerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

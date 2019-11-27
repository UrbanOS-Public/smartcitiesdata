defmodule Estuary.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @elsa_endpoint Application.get_env(:estuary, :elsa_endpoint)
  @event_stream_topic Application.get_env(:estuary, :event_stream_topic)

  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    validate_topic_exists()

    children = [
      {Elsa.Supervisor, elsa_options()}
    ]

    opts = [strategy: :one_for_one, name: Estuary.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp elsa_options do
    [
      endpoints: @elsa_endpoint,
      connection: :estuary_elsa,
      producer: [topic: @event_stream_topic],
      group_consumer: [
        group: "estuary-consumer-group",
        topics: [@event_stream_topic],
        handler: Estuary.MessageHandler,
        config: [
          begin_offset: :earliest,
          offset_reset_policy: :reset_to_earliest
        ]
      ]
    ]
  end

  defp validate_topic_exists do
    case Elsa.Topic.exists?(@elsa_endpoint, @event_stream_topic) do
      true -> :ok
      false -> Elsa.Topic.create(@elsa_endpoint, @event_stream_topic)
    end
  end
end

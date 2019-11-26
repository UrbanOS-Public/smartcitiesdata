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
      {Elsa.Supervisor, elsa_args()}
    ]

    opts = [strategy: :one_for_one, name: Estuary.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp elsa_args do
    start_options = [
      endpoints: @elsa_endpoint,
      connection: :estuary_elsa_supervisor,
      consumer: [
        topic: @event_stream_topic,
        partition: 0,
        begin_offset: :earliest,
        handler: Estuary.MessageHandler
      ]
    ]

    start_options
  end

  defp validate_topic_exists do
    case Elsa.Topic.exists?(@elsa_endpoint, @event_stream_topic) do
      true -> :ok
      false -> Elsa.Topic.create(@elsa_endpoint, @event_stream_topic)
    end
  end
end

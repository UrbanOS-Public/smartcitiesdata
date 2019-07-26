defmodule Flair.Application do
  @moduledoc """
  Flair starts flows for any profiling needed, as well as a connection to kafka.
  """

  use Application

  @message_handler Flair.MessageHandler

  def start(_type, _args) do
    children = [
      {Flair.TableCreator, []},
      {Flair.DurationsFlow, []},
      elsa_consumer()
    ]

    opts = [strategy: :one_for_one, name: Flair.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp elsa_consumer do
    topic = Application.get_env(:flair, :data_topic)

    start_options = [
      brokers: Application.get_env(:flair, :elsa_brokers),
      name: :flair_elsa_supervisor,
      group: "flair-#{topic}",
      topics: [topic],
      handler: @message_handler,
      config: Application.get_env(:flair, :topic_subscriber_config, [])
    ]

    {Elsa.Group.Supervisor, start_options}
  end
end

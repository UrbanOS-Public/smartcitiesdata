defmodule Flair.Application do
  @moduledoc """
  Flair starts flows for any profiling needed, as well as a connection to kafka.
  """
  use Application

  def start(_type, _args) do
    children = [
      table_creator(),
      {Flair.DurationsFlow, []},
      elsa_consumer()
    ]

    opts = [strategy: :one_for_one, name: Flair.Supervisor]

    children
    |> List.flatten()
    |> Supervisor.start_link(opts)
  end

  defp table_creator do
    case Application.get_env(:flair, :table_creator) do
      nil -> []
      mod -> {mod, []}
    end
  end

  defp elsa_consumer do
    topic = Application.get_env(:flair, :data_topic)

    start_options = [
      brokers: Application.get_env(:flair, :elsa_brokers),
      name: :flair_elsa_supervisor,
      group: "flair-#{topic}",
      topics: [topic],
      handler: Flair.MessageHandler,
      config: Application.get_env(:flair, :topic_subscriber_config, [])
    ]

    {Elsa.Group.Supervisor, start_options}
  end
end

defmodule Flair.Application do
  @moduledoc """
  Flair starts flows for any profiling needed, as well as a connection to kafka.
  """
  use Application

  def start(_type, _args) do
    [{Flair.DurationsFlow, []}, elsa_consumer()]
    |> List.flatten()
    |> Supervisor.start_link(strategy: :one_for_one, name: Flair.Supervisor)
  end

  defp elsa_consumer do
    topic = Application.get_env(:flair, :data_topic)

    start_options = [
      endpoints: Application.get_env(:flair, :elsa_brokers),
      connection: :flair_elsa_supervisor,
      group_consumer: [
        group: "flair-#{topic}",
        topics: [topic],
        handler: Flair.MessageHandler,
        config: Application.get_env(:flair, :topic_subscriber_config, [])
      ]
    ]

    {Elsa.Supervisor, start_options}
  end
end

defmodule Flair.Application do
  @moduledoc """
  Flair starts flows for any profiling needed, as well as a connection to kafka.
  """
  use Application

  @topic_reader Application.get_env(:flair, :topic_reader)

  def start(_type, _args) do
    :ok = init_topic_reader()

    [{Flair.Durations.Flow, []}]
    |> Supervisor.start_link(strategy: :one_for_one, name: Flair.Supervisor)
  end

  defp init_topic_reader do
    args = [
      instance: :flair,
      connection: :flair_elsa_supervisor,
      endpoints: Application.get_env(:flair, :elsa_brokers),
      topic: Application.get_env(:flair, :data_topic),
      handler: Flair.MessageHandler,
      topic_subscriber_config: Application.get_env(:flair, :topic_subscriber_config, [])
    ]

    @topic_reader.init(args)
  end
end

defmodule Flair.Durations.Init do
  @moduledoc false

  use Task, restart: :transient

  @topic_reader Application.get_env(:flair, :topic_reader)

  def start_link(_) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run do
    reader = bootstrap_reader()
    writer = Flair.Durations.Consumer.bootstrap()

    ^reader = writer
  end

  defp bootstrap_reader do
    case Application.get_env(:flair, :data_topic) do
      nil ->
        :ok

      topic ->
        init_args(topic)
        |> @topic_reader.init()
    end
  end

  defp init_args(topic) do
    [
      instance: :flair,
      connection: :flair_elsa_supervisor,
      endpoints: Application.get_env(:flair, :elsa_brokers),
      topic: topic,
      handler: Flair.MessageHandler,
      topic_subscriber_config: Application.get_env(:flair, :topic_subscriber_config, [])
    ]
  end
end

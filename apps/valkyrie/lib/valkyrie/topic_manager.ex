defmodule Valkyrie.TopicManager do
  @moduledoc """
  Create Topics in kafka using the Elsa library.
  """
  use Retry

  def create_and_subscribe(topic, opts \\ []) do
    Elsa.create_topic(endpoints(), topic, opts)

    retry with: [10] |> Stream.cycle() |> Stream.take(10) do
      is_topic_ready?(topic) || :error
    after
      true ->
        start_subscriber(topic)
    else
      _ -> raise "Unable to create topic #{topic}"
    end
  end

  def is_topic_ready?(topic) do
    topics =
      endpoints()
      |> Elsa.list_topics()
      |> Enum.map(fn {topic, _partitions} -> topic end)

    topic in topics
  end

  defp start_subscriber(topic) do
    start_options = [
      brokers: endpoints(),
      name: :"name-#{topic}",
      group: "valkyrie-#{topic}",
      topics: [topic],
      handler: Valkyrie.MessageHandler,
      config: Application.get_env(:valkyrie, :topic_subscriber_config, [])
    ]

    DynamicSupervisor.start_child(Valkyrie.Topic.Supervisor, {Elsa.Group.Supervisor, start_options})
  end

  defp endpoints() do
    Application.get_env(:valkyrie, :elsa_brokers)
  end
end

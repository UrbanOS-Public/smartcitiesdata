defmodule Valkyrie.TopicManager do
  @moduledoc """
  Create Topics in kafka using the Elsa library.
  """
  use Retry

  def create_and_subscribe(dataset, topic, opts \\ []) do
    Elsa.create_topic(endpoints(), topic, opts)

    retry with: [10] |> Stream.cycle() |> Stream.take(10) do
      is_topic_ready?(topic) || :error
    after
      true ->
        start_subscriber(dataset, topic)
    else
      _ -> raise "Unable to create topic #{topic}"
    end
  end

  def is_topic_ready?(topic) do
    Elsa.topic?(endpoints(), topic)
  end

  defp start_subscriber(dataset, topic) do
    start_options = [
      dataset: dataset,
      topic: topic
    ]

    DynamicSupervisor.start_child(Valkyrie.Topic.Supervisor, {Valkyrie.DatasetSupervisor, start_options})
  end

  defp endpoints() do
    Application.get_env(:valkyrie, :elsa_brokers)
  end
end

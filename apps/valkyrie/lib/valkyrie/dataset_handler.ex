defmodule Valkyrie.DatasetHandler do
  @moduledoc """
  MessageHandler to receive updated datasets and add to the cache
  """
  use SmartCity.Registry.MessageHandler
  alias SmartCity.Dataset

  def handle_dataset(%Dataset{technical: %{sourceType: source_type}} = dataset)
      when source_type in ["ingest", "streaming"] do
    topics = Valkyrie.TopicManager.setup_topics(dataset)
    start_dataset(dataset, topics.input_topic, topics.output_topic)
  end

  def handle_dataset(_dataset) do
    :ok
  end

  defp start_dataset(dataset, input_topic, output_topic) do
    start_options = [
      dataset: dataset,
      input_topic: input_topic,
      output_topic: output_topic
    ]

    DynamicSupervisor.start_child(Valkyrie.Topic.Supervisor, {Valkyrie.DatasetSupervisor, start_options})
  end
end

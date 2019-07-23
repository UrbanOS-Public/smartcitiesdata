defmodule Valkyrie.DatasetHandler do
  @moduledoc """
  MessageHandler to receive updated datasets and add to the cache
  """
  use SmartCity.Registry.MessageHandler
  alias SmartCity.Dataset
  require Logger

  def handle_dataset(%Dataset{technical: %{sourceType: source_type}} = dataset)
      when source_type in ["ingest", "stream"] do
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

    stop_dataset_supervisor(dataset)
    DynamicSupervisor.start_child(Valkyrie.Dynamic.Supervisor, {Valkyrie.DatasetSupervisor, start_options})
  end

  defp stop_dataset_supervisor(dataset) do
    name = Valkyrie.DatasetSupervisor.name(dataset)

    case Process.whereis(name) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(Valkyrie.Dynamic.Supervisor, pid)
    end
  end
end

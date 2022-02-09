defmodule Alchemist.DatasetProcessor do
  @moduledoc false
  require Logger

  def start(dataset) do
    topics = Alchemist.TopicManager.setup_topics(dataset)
    Logger.debug("#{__MODULE__}: Starting Datatset: #{dataset.id}")

    start_options = [
      dataset: dataset,
      input_topic: topics.input_topic,
      output_topic: topics.output_topic
    ]

    Alchemist.DatasetSupervisor.ensure_started(start_options)
  end

  def stop(dataset_id) do
    Alchemist.DatasetSupervisor.ensure_stopped(dataset_id)
  end

  def delete(dataset_id) do
    Logger.debug("#{__MODULE__}: Deleting Datatset: #{dataset_id}")
    Alchemist.DatasetSupervisor.ensure_stopped(dataset_id)
    Alchemist.TopicManager.delete_topics(dataset_id)
  end
end

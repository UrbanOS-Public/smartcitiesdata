defmodule Valkyrie.DatasetProcessor do
  @moduledoc false
  require Logger

  def start(dataset_id) do
    topics = Valkyrie.TopicManager.setup_topics(dataset_id)
    Logger.debug("#{__MODULE__}: Starting Datatset: #{dataset_id}")

    start_options = [
      dataset_id: dataset_id,
      input_topic: topics.input_topic,
      output_topic: topics.output_topic
    ]

    Valkyrie.DatasetSupervisor.ensure_started(start_options)
  end

  def stop(dataset_id) do
    Valkyrie.DatasetSupervisor.ensure_stopped(dataset_id)
  end

  def delete(dataset_id) do
    Logger.debug("#{__MODULE__}: Deleting Datatset: #{dataset_id}")
    Valkyrie.DatasetSupervisor.ensure_stopped(dataset_id)
    Valkyrie.TopicManager.delete_topics(dataset_id)
  end
end

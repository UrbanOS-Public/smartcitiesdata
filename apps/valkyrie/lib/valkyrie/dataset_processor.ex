defmodule Valkyrie.DatasetProcessor do
  @moduledoc false
  require Logger

  def start(dataset) do
    topics = Valkyrie.TopicManager.setup_topics(dataset)
    Logger.debug("#{__MODULE__}: Starting Datatset: #{dataset.id}")

    start_options = [
      dataset: dataset,
      input_topic: topics.input_topic,
      output_topic: topics.output_topic
    ]

    Valkyrie.DatasetSupervisor.ensure_started(start_options)
  end

  def stop(dataset_id) do
    Valkyrie.DatasetSupervisor.ensure_stopped(dataset_id)
  end
end

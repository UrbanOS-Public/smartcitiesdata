defmodule Alchemist.IngestionProcessor do
  @moduledoc false
  require Logger

  def start(ingestion) do
    topics = Alchemist.TopicManager.setup_topics(ingestion)
    Logger.debug("#{__MODULE__}: Starting Ingestion: #{ingestion.id}")

    start_options = [
      ingestion: ingestion,
      input_topic: topics.input_topic,
      output_topics: topics.output_topics
    ]

    Alchemist.IngestionSupervisor.ensure_started(start_options)
  end

  def stop(ingestion_id) do
    Alchemist.IngestionSupervisor.ensure_stopped(ingestion_id)
  end

  def delete(ingestion) do
    Logger.debug("#{__MODULE__}: Deleting Ingestion: #{ingestion.id}")
    Alchemist.IngestionSupervisor.ensure_stopped(ingestion.id)
    Alchemist.TopicManager.delete_topics(ingestion)
  end
end

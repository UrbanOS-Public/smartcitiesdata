defmodule Alchemist.IngestionProcessor do
  @moduledoc false
  require Logger

  def start(ingestion) do
    topics = Alchemist.TopicManager.setup_topics(ingestion)
    Logger.debug("#{__MODULE__}: Starting Ingestion: #{ingestion.id}")

    start_options = [
      ingestion: ingestion,
      input_topic: topics.input_topic,
      output_topic: topics.output_topic
    ]

    Alchemist.IngestionSupervisor.ensure_started(start_options)
  end

  def stop(ingestion_id) do
    Alchemist.IngestionSupervisor.ensure_stopped(ingestion_id)
  end

  def delete(ingestion_id) do
    Logger.debug("#{__MODULE__}: Deleting Ingestion: #{ingestion_id}")
    Alchemist.IngestionSupervisor.ensure_stopped(ingestion_id)
    Alchemist.TopicManager.delete_topics(ingestion_id)
  end
end

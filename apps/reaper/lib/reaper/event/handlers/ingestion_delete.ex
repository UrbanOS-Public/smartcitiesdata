defmodule Reaper.Event.Handlers.IngestionDelete do
  @moduledoc false

  require Logger

  alias Reaper.Event.Handlers.Helper.StopIngestion
  alias Reaper.Topic.TopicManager
  
  @stop_ingestion Application.compile_env(:reaper, :stop_ingestion, StopIngestion)
  @topic_manager Application.compile_env(:reaper, :topic_manager, TopicManager)

  def handle(%SmartCity.Ingestion{id: ingestion_id}) do
    Logger.debug("#{__MODULE__}: Deleting Ingestion: #{ingestion_id}")

    with :ok <- @stop_ingestion.delete_quantum_job(ingestion_id),
         :ok <- @stop_ingestion.stop_horde_and_cache(ingestion_id),
         :ok <- @topic_manager.delete_topic(ingestion_id) do
      :ok
    else
      error ->
        Logger.error(
          "#{__MODULE__}: Error occurred while deleting the ingestion: #{ingestion_id}, Reason: #{inspect(error)}"
        )
    end
  end
end

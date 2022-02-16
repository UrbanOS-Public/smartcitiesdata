defmodule Reaper.Event.Handlers.IngestionDelete do
  @moduledoc false

  require Logger

  alias Reaper.Event.Handlers.Helper.StopIngestion
  alias Reaper.Topic.TopicManager

  def handle(%SmartCity.Ingestion{id: ingestion_id}) do
    Logger.debug("#{__MODULE__}: Deleting Ingestion: #{ingestion_id}")

    with :ok <- StopIngestion.delete_quantum_job(ingestion_id),
         :ok <- StopIngestion.stop_horde_and_cache(ingestion_id),
         :ok <- TopicManager.delete_topic(ingestion_id) do
      :ok
    else
      error ->
        Logger.error(
          "#{__MODULE__}: Error occurred while deleting the ingestion: #{ingestion_id}, Reason: #{inspect(error)}"
        )
    end
  end
end

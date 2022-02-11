defmodule Alchemist.Event.EventHandler do
  @moduledoc """
  MessageHandler to receive updated ingestions and add to the cache
  """
  alias SmartCity.Ingestion
  use Brook.Event.Handler

  import SmartCity.Event,
    only: [ingestion_update: 0, ingestion_delete: 0]

  require Logger

  def handle_event(%Brook.Event{
        type: ingestion_update(),
        data: %Ingestion{} = ingestion
      }) do
    Logger.debug("#{__MODULE__}: Begin transformation processor for ingestion: #{ingestion.id}")
    Alchemist.IngestionProcessor.start(ingestion)
    merge(:ingestions, ingestion.id, ingestion)
  end

  def handle_event(%Brook.Event{
        type: ingestion_delete(),
        data: %Ingestion{} = ingestion
      }) do
    case Alchemist.IngestionProcessor.delete(ingestion) do
      :ok ->
        Logger.debug("#{__MODULE__}: Deleted ingestion for #{ingestion.id}")

      {:error, error} ->
        Logger.error("#{__MODULE__}: Failed to delete ingestion: #{ingestion.id}, Reason: #{inspect(error)}")
    end

    delete(:ingestions, ingestion.id)
  end

  # defp add_event_count(event_type, author, dataset_id) do
  #   [
  #     app: "alchemist",
  #     author: author,
  #     dataset_id: dataset_id,
  #     event_type: event_type
  #   ]
  #   |> TelemetryEvent.add_event_metrics([:events_handled])
  # end
end

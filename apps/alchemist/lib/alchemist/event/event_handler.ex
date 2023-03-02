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
        data: %Ingestion{} = data
      }) do
    Logger.debug("#{__MODULE__}: Begin transformation processor for ingestion: #{data.id}")

    if Alchemist.IngestionSupervisor.is_started?(data.id) do
      Alchemist.IngestionProcessor.stop(data.id)
    end

    Alchemist.IngestionProcessor.start(data)

    merge(:ingestions, data.id, data)
  rescue
    error ->
      Logger.error("ingestion_update failed to process: #{inspect(error)}")
      DeadLetter.process(data.targetDataset, data.id, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: ingestion_delete(),
        data: %Ingestion{} = data
      }) do
    case Alchemist.IngestionProcessor.delete(data) do
      :ok ->
        Logger.debug("#{__MODULE__}: Deleted ingestion for #{data.id}")

      {:error, error} ->
        Logger.error("#{__MODULE__}: Failed to delete ingestion: #{data.id}, Reason: #{inspect(error)}")
    end

    delete(:ingestions, data.id)
  rescue
    error ->
      Logger.error("ingestion_delete failed to process: #{inspect(error)}")
      DeadLetter.process(data.targetDataset, data.id, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
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

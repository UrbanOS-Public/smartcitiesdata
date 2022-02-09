defmodule Alchemist.Event.EventHandler do
  @moduledoc """
  MessageHandler to receive updated ingestions and add to the cache
  """
  alias SmartCity.Ingestion
  use Brook.Event.Handler

  import SmartCity.Event,
    only: [ingestion_update: 0]

  require Logger

  def handle_event(%Brook.Event{
        type: ingestion_update(),
        data: %Ingestion{} = ingestion
      }) do
    Logger.debug("#{__MODULE__}: Begin transformation processor for ingestion: #{ingestion.id}")
    IO.inspect(ingestion, label: "Begin transformation processor for ingestion: #{ingestion.id}")
    Alchemist.IngestionProcessor.start(ingestion)
    merge(:ingestions, ingestion.id, ingestion)
  end

  # TODOLater: Support ingestion deletions
  # https://github.com/UrbanOS-Public/internal/issues/535
  # def handle_event(%Brook.Event{
  #       type: dataset_delete(),
  #       data: %Dataset{} = dataset,
  #       author: author
  #     }) do
  #   dataset_delete()
  #   |> add_event_count(author, dataset.id)

  #   case Alchemist.IngestionProcessor.delete(dataset.id) do
  #     :ok ->
  #       Logger.debug("#{__MODULE__}: Deleted dataset for dataset: #{dataset.id}")

  #     {:error, error} ->
  #       Logger.error("#{__MODULE__}: Failed to delete dataset for dataset: #{dataset.id}, Reason: #{inspect(error)}")
  #   end

  #   delete(:datasets, dataset.id)
  # end

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

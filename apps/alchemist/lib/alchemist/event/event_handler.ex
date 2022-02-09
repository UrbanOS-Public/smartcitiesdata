defmodule Alchemist.Event.EventHandler do
  @moduledoc """
  MessageHandler to receive updated datasets and add to the cache
  """
  alias SmartCity.Ingestion
  use Brook.Event.Handler

  import SmartCity.Event,
    only: [ingestion_update: 0]

  require Logger

  def handle_event(%Brook.Event{
        type: ingestion_update(),
        data: %Ingestion{targetDataset: targetDataset} = ingestion
      }) do
    Logger.debug("#{__MODULE__}: Begin transformation for dataset: #{targetDataset}")
    IO.inspect(ingestion, label: "I got ingestion")
    # Alchemist.IngestionProcessor.start(targetDataset)
    # merge(:ingestions, ingestion.id, ingestion)
    :discard
  end

  # TODO: Support ingestion deletions
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

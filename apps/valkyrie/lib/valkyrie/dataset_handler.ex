defmodule Valkyrie.DatasetHandler do
  @moduledoc """
  MessageHandler to receive updated datasets and add to the cache
  """
  alias SmartCity.Dataset
  use Brook.Event.Handler
  import SmartCity.Event, only: [data_ingest_start: 0, data_standardization_end: 0, dataset_delete: 0]
  require Logger

  def handle_event(%Brook.Event{
        type: data_ingest_start(),
        data: %Dataset{technical: %{sourceType: source_type}} = dataset
      })
      when source_type in ["ingest", "stream"] do
    Logger.debug("#{__MODULE__}: Preparing standardization for dataset: #{dataset.id}")
    Valkyrie.DatasetProcessor.start(dataset)
    merge(:datasets, dataset.id, dataset)
  end

  def handle_event(%Brook.Event{
        type: data_standardization_end(),
        data: %{"dataset_id" => dataset_id}
      }) do
    Valkyrie.DatasetProcessor.stop(dataset_id)
    Logger.debug("#{__MODULE__}: Standardization finished for dataset: #{dataset_id}")
    delete(:datasets, dataset_id)
  end

  def handle_event(%Brook.Event{
        type: dataset_delete(),
        data: %Dataset{} = dataset
      }) do
    case Valkyrie.DatasetProcessor.delete(dataset.id) do
      :ok ->
        delete(:datasets, dataset.id)
        Logger.debug("#{__MODULE__}: Deleted dataset for dataset: #{dataset.id}")

      {:error, error} ->
        Logger.error("#{__MODULE__}: Failed to delete dataset for dataset: #{dataset.id}, Reason: #{inspect(error)}")
    end
  end
end

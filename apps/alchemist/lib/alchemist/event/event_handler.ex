defmodule Alchemist.Event.EventHandler do
  @moduledoc """
  MessageHandler to receive updated datasets and add to the cache
  """
  alias SmartCity.Dataset
  use Brook.Event.Handler

  import SmartCity.Event,
    only: [data_ingest_start: 0, data_standardization_end: 0, dataset_delete: 0, dataset_update: 0]

  require Logger
  @instance_name Alchemist.instance_name()

  def handle_event(%Brook.Event{
        type: data_ingest_start(),
        data: %Dataset{technical: %{sourceType: source_type}} = dataset,
        author: author
      })
      when source_type in ["ingest", "stream"] do
    data_ingest_start()
    |> add_event_count(author, dataset.id)

    Logger.debug("#{__MODULE__}: Preparing standardization for dataset: #{dataset.id}")
    Alchemist.DatasetProcessor.start(dataset)
    merge(:datasets, dataset.id, dataset)
  end

  def handle_event(%Brook.Event{
        type: data_standardization_end(),
        data: %{"dataset_id" => dataset_id},
        author: author
      }) do
    data_standardization_end()
    |> add_event_count(author, dataset_id)

    Alchemist.DatasetProcessor.stop(dataset_id)
    Logger.debug("#{__MODULE__}: Standardization finished for dataset: #{dataset_id}")
    delete(:datasets, dataset_id)
  end

  def handle_event(%Brook.Event{
        type: dataset_update(),
        data: %Dataset{} = dataset,
        author: author
      }) do
    dataset_update()
    |> add_event_count(author, dataset.id)

    if Alchemist.DatasetSupervisor.is_started?(dataset.id) do
      Alchemist.DatasetProcessor.stop(dataset.id)
      Alchemist.DatasetProcessor.start(dataset)
    end

    merge(:datasets, dataset.id, dataset)
  end

  def handle_event(%Brook.Event{
        type: dataset_delete(),
        data: %Dataset{} = dataset,
        author: author
      }) do
    dataset_delete()
    |> add_event_count(author, dataset.id)

    case Alchemist.DatasetProcessor.delete(dataset.id) do
      :ok ->
        Logger.debug("#{__MODULE__}: Deleted dataset for dataset: #{dataset.id}")

      {:error, error} ->
        Logger.error("#{__MODULE__}: Failed to delete dataset for dataset: #{dataset.id}, Reason: #{inspect(error)}")
    end

    delete(:datasets, dataset.id)
  end

  defp add_event_count(event_type, author, dataset_id) do
    [
      app: "alchemist",
      author: author,
      dataset_id: dataset_id,
      event_type: event_type
    ]
    |> TelemetryEvent.add_event_metrics([:events_handled])
  end
end

defmodule Valkyrie.Event.EventHandler do
  @moduledoc """
  MessageHandler to receive updated datasets and add to the cache
  """
  alias SmartCity.Dataset
  alias SmartCity.Ingestion
  use Brook.Event.Handler

  import SmartCity.Event,
    only: [
      data_extract_start: 0,
      data_ingest_start: 0,
      data_standardization_end: 0,
      dataset_delete: 0,
      dataset_update: 0
    ]

  require Logger
  @instance_name Valkyrie.instance_name()

  def handle_event(%Brook.Event{
        type: data_ingest_start(),
        data: %Ingestion{targetDatasets: target_dataset_ids} = data,
        author: author
      }) do
    Logger.info("Ingestion: #{data.id} - Received data_ingest_start event from #{author}")

    Enum.each(target_dataset_ids, fn target_dataset_id ->
      add_event_count(data_ingest_start(), author, target_dataset_id)
      dataset = Brook.get!(@instance_name, :datasets, target_dataset_id)

      if dataset != nil do
        Logger.debug("#{__MODULE__}: Preparing standardization for dataset: #{target_dataset_id}")
        Valkyrie.DatasetProcessor.start(dataset)
      else
        Logger.debug("Could not find dataset_id: #{target_dataset_id} in ingestion: #{data.id}")
      end
    end)

    :ok
  rescue
    error ->
      Logger.error("data_ingest_start failed to process: #{inspect(error)}")
      DeadLetter.process(data.targetDatasets, data.id, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: data_extract_start(),
        data: %Ingestion{targetDatasets: target_dataset_ids} = data,
        author: author
      }) do
    Logger.info("Ingestion: #{data.id} - Received data_extract_start event from #{author}")

    Enum.each(target_dataset_ids, fn target_dataset_id ->
      add_event_count(data_ingest_start(), author, target_dataset_id)
      dataset = Brook.get!(@instance_name, :datasets, target_dataset_id)

      if dataset != nil do
        if not Valkyrie.DatasetSupervisor.is_started?(target_dataset_id) do
          Valkyrie.DatasetProcessor.start(dataset)
        end
      else
        Logger.error("Could not find dataset_id: #{target_dataset_id} in ingestion: #{data.id}")
      end
    end)

    :ok
  rescue
    error ->
      Logger.error("data_extract_start failed to process: #{inspect(error)}")
      DeadLetter.process(data.targetDatasets, data.id, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: data_standardization_end(),
        data: %{"dataset_id" => dataset_id} = data,
        author: author
      }) do
    Logger.info("Dataset: #{dataset_id} - Received data_standardization_end event from #{author}")

    data_standardization_end()
    |> add_event_count(author, dataset_id)

    Valkyrie.DatasetProcessor.stop(dataset_id)
    Logger.debug("#{__MODULE__}: Standardization finished for dataset: #{dataset_id}")
    delete(:datasets, dataset_id)
  rescue
    error ->
      Logger.error("data_standardization_end failed to process: #{inspect(error)}")
      DeadLetter.process([dataset_id], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: dataset_update(),
        data: %Dataset{} = data,
        author: author
      }) do
    Logger.info("Dataset: #{data.id} - Received dataset_update event from #{author}")

    dataset_update()
    |> add_event_count(author, data.id)

    if Valkyrie.DatasetSupervisor.is_started?(data.id) do
      Valkyrie.DatasetProcessor.stop(data.id)
      Valkyrie.DatasetProcessor.start(data)
    end

    merge(:datasets, data.id, data)
  rescue
    error ->
      Logger.error("dataset_update failed to process: #{inspect(error)}")
      DeadLetter.process([data.id], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: dataset_delete(),
        data: %Dataset{} = data,
        author: author
      }) do
    Logger.info("Dataset: #{data.id} - Received dataset_delete event from #{author}")

    dataset_delete()
    |> add_event_count(author, data.id)

    case Valkyrie.DatasetProcessor.delete(data.id) do
      :ok ->
        Logger.debug("#{__MODULE__}: Deleted dataset for dataset: #{data.id}")

      {:error, error} ->
        Logger.error("#{__MODULE__}: Failed to delete dataset for dataset: #{data.id}, Reason: #{inspect(error)}")
    end

    delete(:datasets, data.id)
  rescue
    error ->
      Logger.error("dataset_delete failed to process: #{inspect(error)}")
      DeadLetter.process([data.id], nil, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  defp add_event_count(event_type, author, dataset_id) do
    [
      app: "valkyrie",
      author: author,
      dataset_id: dataset_id,
      event_type: event_type
    ]
    |> TelemetryEvent.add_event_metrics([:events_handled])
  end
end

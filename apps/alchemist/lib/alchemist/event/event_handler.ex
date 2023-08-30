defmodule Alchemist.Event.EventHandler do
  @moduledoc """
  MessageHandler to receive updated ingestions and add to the cache
  """
  alias SmartCity.Ingestion
  use Brook.Event.Handler

  import SmartCity.Event,
    only: [ingestion_update: 0, ingestion_delete: 0, data_extract_start: 0]

  require Logger

  def handle_event(%Brook.Event{
        type: ingestion_update(),
        data: %Ingestion{} = data
      }) do
    Logger.info("Ingestion: #{data.id} - Received ingestion_update event")

    if Alchemist.IngestionSupervisor.is_started?(data.id) do
      Alchemist.IngestionProcessor.stop(data.id)
    end

    if not Enum.empty?(data.targetDatasets) do
      Alchemist.IngestionProcessor.start(data)
    end

    merge(:ingestions, data.id, data)
  rescue
    error ->
      Logger.error("ingestion_update failed to process: #{inspect(error)}")
      DeadLetter.process(data.targetDatasets, data.id, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: ingestion_delete(),
        data: %Ingestion{} = data
      }) do
    Logger.info("Ingestion: #{data.id} - Received ingestion_delete event")

    case Alchemist.IngestionProcessor.delete(data) do
      :ok ->
        Logger.info("#{__MODULE__}: Deleted ingestion for #{data.id}")

      {:error, error} ->
        Logger.error("#{__MODULE__}: Failed to delete ingestion: #{data.id}, Reason: #{inspect(error)}")
    end

    delete(:ingestions, data.id)
  rescue
    error ->
      Logger.error("ingestion_delete failed to process: #{inspect(error)}")
      DeadLetter.process(data.targetDatasets, data.id, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end

  def handle_event(%Brook.Event{
        type: data_extract_start(),
        data: %Ingestion{} = data
      }) do
    Logger.info("Ingestion: #{data.id} - Received data_extract_start event")

    if not Alchemist.IngestionSupervisor.is_started?(data.id) and not Enum.empty?(data.targetDatasets) do
      Alchemist.IngestionProcessor.start(data)
    end

    :ok
  rescue
    error ->
      Logger.error("data_extract_start failed to process: #{inspect(error)}")
      DeadLetter.process(data.targetDatasets, data.id, data, Atom.to_string(@instance_name), reason: inspect(error))
      :discard
  end
end

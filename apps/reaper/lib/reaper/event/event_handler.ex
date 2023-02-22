defmodule Reaper.Event.EventHandler do
  @moduledoc "This module processes all events for Reaper"
  use Brook.Event.Handler
  require Logger

  import SmartCity.Event,
    only: [
      data_ingest_start: 0,
      data_extract_start: 0,
      data_extract_end: 0,
      dataset_delete: 0,
      ingestion_update: 0,
      ingestion_delete: 0,
      error_ingestion_update: 0
    ]

  alias Reaper.Collections.Extractions
  alias Reaper.Event.Handlers.IngestionDelete
  alias SmartCity.{Dataset}

  @instance_name Reaper.instance_name()

  def handle_event(%Brook.Event{
        type: ingestion_update(),
        data: %SmartCity.Ingestion{} = data
      }) do
    ingestion_update()
    |> add_event_count(data.targetDataset)

    Extractions.update_ingestion(data)
    Reaper.Event.Handlers.IngestionUpdate.handle(data)
  rescue
    error ->
      Logger.error("ingestion_update failed to process.")
      DeadLetter.process(data.targetDataset, data.id, data, Atom.to_string(@instance_name), reason: error.__struct__)
      :discard
  end

  def handle_event(%Brook.Event{
        type: ingestion_delete(),
        data: %SmartCity.Ingestion{} = data
      }) do
    ingestion_delete()
    |> add_event_count(data.id)

    Reaper.Event.Handlers.IngestionDelete.handle(data)
    Extractions.delete_ingestion(data.id)

  rescue
    error ->
      Logger.error("ingestion_delete failed to process.")
      DeadLetter.process(data.targetDataset, data.id, data, Atom.to_string(@instance_name), reason: error.__struct__)
      :discard
  end

  def handle_event(%Brook.Event{
        type: data_extract_start(),
        data: %SmartCity.Ingestion{} = data
      }) do
    data_extract_start()
    |> add_event_count(data.targetDataset)

    if Extractions.is_enabled?(data.id) do
      Reaper.Horde.Supervisor.start_data_extract(data)

      if Extractions.should_send_data_ingest_start?(data) do
        Brook.Event.send(@instance_name, data_ingest_start(), :reaper, data)
      end

      Extractions.update_started_timestamp(data.id)
    end

    :ok

  rescue
    error ->
      Logger.error("data_extract_start failed to process.")
      DeadLetter.process(data.targetDataset, data.id, data, Atom.to_string(@instance_name), reason: error.__struct__)
      :discard
  end

  def handle_event(%Brook.Event{
        type: data_extract_end(),
        data: %{
          "dataset_id" => dataset_id,
          "extract_start_unix" => _extract_start,
          "ingestion_id" => ingestion_id,
          "msgs_extracted" => _msg_target
        } = data
      }) do
    data_extract_end()
    |> add_event_count(dataset_id)

    Extractions.update_last_fetched_timestamp(ingestion_id)

  rescue
    error ->
      Logger.error("data_extract_end failed to process.")
      DeadLetter.process(dataset_id, ingestion_id, data, Atom.to_string(@instance_name), reason: error.__struct__)
      :discard
  end

  def handle_event(%Brook.Event{
        type: dataset_delete(),
        data: %Dataset{} = data
      }) do
    dataset_delete()
    |> add_event_count(data.id)

    {:ok, extractions} = Brook.ViewState.get_all(@instance_name, :extractions)

    extractions_to_delete =
      Enum.filter(extractions, fn {key, e} ->
        with {:ok, ingestion} <- Map.fetch(e, "ingestion") do
          ingestion[:targetDataset] == data[:id]
        else
          :error -> Logger.error("Extraction #{key} does not have an Ingestion object")
        end
      end)

    Enum.each(
      extractions_to_delete,
      fn {_id, extraction} ->
        if extraction["ingestion"] do
          IngestionDelete.handle(extraction["ingestion"])
        end
      end
    )

    :ok

  rescue
    error ->
      Logger.error("data_extract_start failed to process.")
      DeadLetter.process(data.targetDataset, data.id, data, Atom.to_string(@instance_name), reason: error.__struct__)
      :discard
  end

  defp add_event_count(event_type, dataset_id) do
    [
      app: "reaper",
      author: "reaper",
      dataset_id: dataset_id,
      event_type: event_type
    ]
    |> TelemetryEvent.add_event_metrics([:events_handled])
  end
end

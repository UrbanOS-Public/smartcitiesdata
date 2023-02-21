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
        data: %SmartCity.Ingestion{} = ingestion
      }) do
    ingestion_delete()
    |> add_event_count(ingestion.id)

    Reaper.Event.Handlers.IngestionDelete.handle(ingestion)
    Extractions.delete_ingestion(ingestion.id)
  end

  def handle_event(%Brook.Event{
        type: data_extract_start(),
        data: %SmartCity.Ingestion{} = ingestion
      }) do
    data_extract_start()
    |> add_event_count(ingestion.targetDataset)

    if Extractions.is_enabled?(ingestion.id) do
      Reaper.Horde.Supervisor.start_data_extract(ingestion)

      if Extractions.should_send_data_ingest_start?(ingestion) do
        Brook.Event.send(@instance_name, data_ingest_start(), :reaper, ingestion)
      end

      Extractions.update_started_timestamp(ingestion.id)
    end

    :ok
  end

  def handle_event(%Brook.Event{
        type: data_extract_end(),
        data: %{
          "dataset_id" => dataset_id,
          "extract_start_unix" => _extract_start,
          "ingestion_id" => ingestion_id,
          "msgs_extracted" => _msg_target
        }
      }) do
    data_extract_end()
    |> add_event_count(dataset_id)

    Extractions.update_last_fetched_timestamp(ingestion_id)
  end

  def handle_event(%Brook.Event{
        type: dataset_delete(),
        data: %Dataset{} = dataset
      }) do
    dataset_delete()
    |> add_event_count(dataset.id)

    {:ok, extractions} = Brook.ViewState.get_all(@instance_name, :extractions)

    extractions_to_delete =
      Enum.filter(extractions, fn {key, e} ->
        with {:ok, ingestion} <- Map.fetch(e, "ingestion") do
          ingestion[:targetDataset] == dataset[:id]
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

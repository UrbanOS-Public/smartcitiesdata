defmodule Reaper.Event.Handler do
  @moduledoc "This modules processes all events for Reaper"
  use Brook.Event.Handler

  alias Reaper.Collections.{Extractions, FileIngestions}

  import SmartCity.Event,
    only: [
      dataset_update: 0,
      data_ingest_start: 0,
      data_extract_start: 0,
      data_extract_end: 0,
      file_ingest_start: 0,
      file_ingest_end: 0
    ]

  def handle_event(%Brook.Event{type: dataset_update(), data: %SmartCity.Dataset{} = dataset}) do
    Reaper.Event.Handlers.DatasetUpdate.handle(dataset)
  end

  def handle_event(%Brook.Event{type: data_extract_start(), data: %SmartCity.Dataset{} = dataset}) do
    Reaper.Horde.Supervisor.start_data_extract(dataset)

    if Extractions.should_send_data_ingest_start?(dataset) do
      Brook.Event.send(data_ingest_start(), :reaper, dataset)
    end

    Extractions.update_dataset(dataset)
  end

  def handle_event(%Brook.Event{type: data_extract_end(), data: %SmartCity.Dataset{} = dataset}) do
    Extractions.update_last_fetched_timestamp(dataset.id)
  end

  def handle_event(%Brook.Event{type: file_ingest_start(), data: %SmartCity.Dataset{} = dataset}) do
    Reaper.Horde.Supervisor.start_file_ingest(dataset)
    FileIngestions.update_dataset(dataset)
  end

  def handle_event(%Brook.Event{type: file_ingest_end(), data: %SmartCity.Dataset{} = dataset}) do
    FileIngestions.update_last_fetched_timestamp(dataset.id)
  end
end

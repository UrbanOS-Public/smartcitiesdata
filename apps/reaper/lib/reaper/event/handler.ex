defmodule Reaper.Event.Handler do
  @moduledoc "This module will process dataset:update events"
  use Brook.Event.Handler

  alias Reaper.Collections.Extractions

  import SmartCity.Event,
    only: [
      dataset_update: 0,
      dataset_extract_start: 0,
      dataset_extract_complete: 0,
      hosted_file_start: 0,
      file_upload: 0
    ]

  require Logger

  def handle_event(%Brook.Event{type: dataset_update(), data: %SmartCity.Dataset{} = dataset}) do
    Reaper.Event.Handlers.DatasetUpdate.handle(dataset)
  end

  def handle_event(%Brook.Event{type: dataset_extract_start(), data: %SmartCity.Dataset{} = dataset}) do
    # Start process to ingest data
    Extractions.update_dataset(dataset)
  end

  def handle_event(%Brook.Event{type: dataset_extract_complete(), data: %SmartCity.Dataset{} = dataset}) do
    Extractions.update_last_fetched_timestamp(dataset.id)
  end

  def handle_event(%Brook.Event{type: hosted_file_start(), data: %SmartCity.Dataset{} = dataset}) do
    # Start process to download file

    # HostedDownloads.update_dataset(dataset)
  end

  def handle_event(%Brook.Event{type: file_upload(), data: %SmartCity.Dataset{} = dataset}) do
    # HostedDownloads.update_last_fetched_timestamp(dataset.id)
  end
end

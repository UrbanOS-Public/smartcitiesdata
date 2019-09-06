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

  def handle_event(%Brook.Event{
        type: dataset_extract_start(),
        data: %SmartCity.Dataset{technical: %{sourceType: "stream"}} = dataset
      }) do
    handle_extraction(dataset)

    if Extractions.should_send_streaming_ingest_start?(dataset.id) do
      Brook.Event.send("data:ingest:start", :reaper, dataset)
    end

    Extractions.update_streaming_dataset_status(dataset.id)
  end

  def handle_event(%Brook.Event{type: dataset_extract_start(), data: %SmartCity.Dataset{} = dataset}) do
    handle_extraction(dataset)
    Brook.Event.send("data:ingest:start", :reaper, dataset)
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

  defp handle_extraction(dataset) do
    # Test this?
    send_extract_complete_event = fn ->
      Brook.Event.send(dataset_extract_complete(), :reaper, dataset)
    end

    Horde.Supervisor.start_child(
      Reaper.Horde.Supervisor,
      {Reaper.ExtractionTask, %{dataset: dataset, completion_callback: send_extract_complete_event}}
    )

    Extractions.update_dataset(dataset)
  end
end

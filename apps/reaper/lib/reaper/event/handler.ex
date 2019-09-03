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
      file_upload: 0,
      hosted_file_complete: 0
    ]

  require Logger

  def handle_event(%Brook.Event{type: dataset_update(), data: %SmartCity.Dataset{} = dataset}) do
    :ok = Reaper.Event.Handlers.DatasetUpdate.handle(dataset)
    :discard
  end

  def handle_event(%Brook.Event{type: dataset_extract_start(), data: %SmartCity.Dataset{} = dataset}) do
    # Start process to ingest data

    # merge(:extractions, dataset.id, %{dataset: dataset}
    Extractions.update_dataset(dataset)

    :ok
  end

  def handle_event(%Brook.Event{type: dataset_extract_complete(), data: %SmartCity.Dataset{} = dataset}) do
    # Extractions.update_last_fetched_timestamp(dataset.id)
    {:merge, :extractions, dataset.id, %{last_fetched_timestamp: NaiveDateTime.utc_now()}}
  end

  def handle_event(%Brook.Event{type: hosted_file_start(), data: data}) do
    # {:merge, :hosted_downloads, :key, :value}
  end

  def handle_event(%Brook.Event{type: file_upload(), data: data}) do
    # {:delete, :hosted_downloads, :key}
  end

end

# if cadence == "never", do nothing
# if cadence == "once", send dataset:extract:start event
# if cadence == "cron expresssion", add job to quantum

# case ReaperConfig.from_dataset(dataset) do
#   {:ok, reaper_config} ->
#     Logger.debug(fn -> "#{__MODULE__}: Got #{dataset_update()} event processing #{reaper_config.dataset_id}" end)
#     ConfigServer.process_reaper_config(reaper_config)
#     {:merge, :reaper_config, reaper_config.dataset_id, reaper_config}

#   {:error, reason} ->
#     Logger.error("Failed to process #{dataset_update()} event, reason: #{inspect(reason)}")
#     :discard
# end

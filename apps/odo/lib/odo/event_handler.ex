defmodule Odo.EventHandler do
  @moduledoc """
  This module will process events that are passed into odo, initiating the transformation and upload
  """
  require Logger
  use Brook.Event.Handler
  import SmartCity.Event, only: [file_ingest_end: 0, error_file_ingest: 0]
  alias SmartCity.HostedFile

  def handle_event(%Brook.Event{type: file_ingest_end(), data: %HostedFile{mime_type: "application/zip"} = file_data}) do
    case Odo.ConversionMap.generate(file_data) do
      {:ok, conversion_map} ->
        Task.Supervisor.start_child(
          Odo.TaskSupervisor,
          Odo.FileProcessor,
          :process,
          [conversion_map],
          restart: :transient
        )

        Logger.debug("Processing file for dataset: #{file_data.dataset_id}: shapefile to geojson}")
        {:merge, :file_conversions, "#{file_data.dataset_id}_#{file_data.key}", file_data}

      {:error, reason} ->
        Odo.MetricsRecorder.record_file_conversion_metrics(file_data.dataset_id, file_data.key, false)
        Logger.error("Error processing file conversion: #{reason}")
        :discard
    end
  end

  def handle_event(%Brook.Event{
        type: file_ingest_end(),
        data: %HostedFile{mime_type: "application/geo+json"} = file_data
      }) do
    old_key = String.replace(file_data.key, ".geojson", ".shapefile")

    Logger.debug("Geojson file converted for dataset: #{file_data.dataset_id}, removing from state view")
    {:delete, :file_conversions, "#{file_data.dataset_id}_#{old_key}"}
  end

  def handle_event(%Brook.Event{type: error_file_ingest(), data: %{dataset_id: id, key: key}}) do
    Logger.warn("Conversion of #{key} for dataset #{id} failed; removing from view state")
    {:delete, :file_conversions, "#{id}_#{key}"}
  end
end

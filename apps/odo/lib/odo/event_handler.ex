defmodule Odo.EventHandler do
  @moduledoc """
  This module will process events that are passed into odo, initiating the transformation and upload
  """
  require Logger
  use Brook.Event.Handler
  import SmartCity.Event, only: [file_upload: 0]
  alias SmartCity.HostedFile

  def handle_event(%Brook.Event{type: file_upload(), data: %HostedFile{mime_type: "application/zip"} = file_data}) do
    Task.Supervisor.start_child(
      Odo.TaskSupervisor,
      Odo.FileProcessor,
      :process,
      [file_data],
      restart: :transient
    )

    Logger.debug("Processing file for dataset: #{file_data.dataset_id}: shapefile to geojson}")
    {:merge, :file_conversions, "#{file_data.dataset_id}_#{file_data.key}", file_data}
  end

  def handle_event(%Brook.Event{type: file_upload(), data: %HostedFile{mime_type: "application/geo+json"} = file_data}) do
    old_key = String.replace(file_data.key, ".geojson", ".shapefile")

    Logger.debug("Geojson file converted for dataset: #{file_data.dataset_id}, removing from state view")
    {:delete, :file_conversions, "#{file_data.dataset_id}_#{old_key}"}
  end
end

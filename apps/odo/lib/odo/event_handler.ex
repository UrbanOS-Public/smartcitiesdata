defmodule Odo.EventHandler do
  @moduledoc """
  This module will process events that are passed into odo, initiating the transformation and upload
  """
  use Brook.Event.Handler
  import SmartCity.Event, only: [file_upload: 0]
  alias SmartCity.Event.FileUpload

  def handle_event(%Brook.Event{type: file_upload(), data: %{"mime_type" => "application/zip"} = data}) do
    {:ok, file_event} = FileUpload.new(data)

    Task.Supervisor.start_child(
      Odo.TaskSupervisor,
      Odo.FileProcessor,
      :process,
      [file_event],
      restart: :transient
    )

    {:merge, :file_conversions, "#{file_event.dataset_id}_#{file_event.key}", file_event}
  end

  def handle_event(%Brook.Event{type: file_upload(), data: %{"mime_type" => "application/geo+json"} = data}) do
    old_key = String.replace(data["key"], ".geojson", ".shapefile")
    {:delete, :file_conversions, "#{data["dataset_id"]}_#{old_key}"}
  end
end

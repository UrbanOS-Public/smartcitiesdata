defmodule Odo.EventHandler do
  @moduledoc """
  This module will process events that are passed into odo, initiating the transformation and upload
  """
  use Brook.Event.Handler
  import SmartCity.Events, only: [file_uploaded: 0]
  alias SmartCity.Events.FileUploaded

  def handle_event(%Brook.Event{type: file_uploaded(), data: %{"mime_type" => "application/zip"} = data}) do
    Task.Supervisor.start_child(Odo.ShapefileTaskSupervisor, Odo.ShapefileProcessor.process(data))
    {:merge, :file_conversions, "#{data["dataset_id"]}_#{data["key"]}", data}
  end

  def handle_event(%Brook.Event{type: file_uploaded(), data: %{"mime_type" => "application/geo+json"} = data}) do
    old_key = String.replace(data["key"], ".geojson", ".shapefile")
    {:delete, :file_conversions, "#{data["dataset_id"]}_#{old_key}"}
  end
end

defmodule Odo.Init do
  use Task, restart: :transient

  def start_link(_arg) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    :ok
    # Brook.get_all_values!(:file_conversions)
    # |> Enum.each(&start_them_up/1)
  end
end

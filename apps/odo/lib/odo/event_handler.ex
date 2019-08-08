defmodule Odo.EventHandler do
  @moduledoc """
  This module will process events that are passed into odo, initiating the transformation and upload
  """
  use Brook.Event.Handler
  import SmartCity.Events, only: [file_uploaded: 0]

  def handle_event(%Brook.Event{type: file_uploaded(), data: %{"mime_type" => "application/zip"} = data}) do
    Task.Supervisor.start_child(Odo.ShapefileTaskSupervisor, Odo.ShapefileProcessor, :process, [data])
    # We will probably want to save app state so that we don't reprocess all files on a pod restart
    :discard
  end
end

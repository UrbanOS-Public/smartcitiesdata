defmodule Odo.MessageHandler do
  @moduledoc """
  This module will process messages that are passed into odo, starting the transformation and upload
  """

  @doc """
  Processes a `SmartCity.Dataset` and begins transformation
  """
  @spec handle_dataset(SmartCity.Dataset.t()) ::
          {:ok, String.t()} | DynamicSupervisor.on_start_child() | nil
  def handle_dataset(%SmartCity.Dataset{technical: %{sourceFormat: "shapefile", sourceType: "host"}} = dataset) do
    Task.Supervisor.start_child(Odo.ShapefileTaskSupervisor, fn -> Odo.ShapefileProcessor.process(dataset) end)
  end
end

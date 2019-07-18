defmodule Odo.MessageHandler do
  @moduledoc """
  This module will process messages that are passed into odo, starting the transformation and upload
  """
  require Logger
  use SmartCity.Registry.MessageHandler

  @doc """
  Processes a `SmartCity.Dataset` and begins transformation
  """
  @spec handle_dataset(SmartCity.Dataset.t()) ::
          {:ok, String.t()} | DynamicSupervisor.on_start_child() | nil
  def handle_dataset(%SmartCity.Dataset{} = dataset) do
    start_worker(dataset)
  end

  def start_worker(dataset) do
    opts = [
      dataset: dataset
    ]

    DynamicSupervisor.start_child(
      Odo.ShapefileProcessorSupervisor,
      {Odo.ShapefileProcessor, opts}
    )
  end
end

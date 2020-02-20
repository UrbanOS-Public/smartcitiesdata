defmodule Reaper.Event.Handlers.DatasetDelete do
  @moduledoc false

  require Logger

  alias Reaper.Event.Handlers.Helper
  alias Reaper.Topic.Manager

  def handle(%SmartCity.Dataset{id: dataset_id}) do
    Logger.debug("#{__MODULE__}: Deleting Datatset: #{dataset_id}")

    with :ok <- Helper.deactivate_quantum_job(dataset_id),
         :ok <- Helper.retry_stopping_dataset(Reaper.Horde.Registry, dataset_id),
         :ok <- Helper.retry_stopping_dataset(Reaper.Cache.Registry, dataset_id),
         :ok <- Manager.delete_topic(dataset_id) do
      :ok
    end
  end
end

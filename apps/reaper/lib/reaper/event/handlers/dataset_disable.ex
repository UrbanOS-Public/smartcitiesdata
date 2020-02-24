defmodule Reaper.Event.Handlers.DatasetDisable do
  @moduledoc false
  alias Reaper.Event.Handlers.Helper.DatasetHelper

  def handle(%SmartCity.Dataset{id: dataset_id}) do
    with :ok <- DatasetHelper.deactivate_quantum_job(dataset_id),
         :ok <- DatasetHelper.retry_stopping_dataset(Reaper.Horde.Registry, dataset_id),
         :ok <- DatasetHelper.retry_stopping_dataset(Reaper.Cache.Registry, dataset_id) do
      :ok
    else
      error -> error
    end
  end
end

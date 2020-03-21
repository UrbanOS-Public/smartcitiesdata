defmodule Reaper.Event.Handlers.DatasetDisable do
  @moduledoc false
  alias Reaper.Event.Handlers.Helper.StopDataset

  def handle(%SmartCity.Dataset{id: dataset_id}) do
    with :ok <- StopDataset.deactivate_quantum_job(dataset_id),
         :ok <- StopDataset.stop_horde_and_cache(dataset_id) do
      :ok
    else
      error -> error
    end
  end
end

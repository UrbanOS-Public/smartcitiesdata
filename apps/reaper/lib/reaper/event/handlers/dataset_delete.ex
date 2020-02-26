defmodule Reaper.Event.Handlers.DatasetDelete do
  @moduledoc false

  require Logger

  alias Reaper.Event.Handlers.Helper.StopDataset
  alias Reaper.Topic.TopicManager

  def handle(%SmartCity.Dataset{id: dataset_id}) do
    Logger.debug("#{__MODULE__}: Deleting Datatset: #{dataset_id}")

    with :ok <- StopDataset.delete_quantum_job(dataset_id),
         :ok <- StopDataset.stop_horde_and_cache(dataset_id),
         :ok <- TopicManager.delete_topic(dataset_id) do
      :ok
    else
      error ->
        Logger.error(
          "#{__MODULE__}: Error occured while deleting the dataset: #{dataset_id}, Reason: #{inspect(error)}"
        )
    end
  end
end

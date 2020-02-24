defmodule Reaper.Event.Handlers.DatasetDelete do
  @moduledoc false

  require Logger

  alias Reaper.Event.Handlers.Helper.DatasetHelper
  alias Reaper.Topic.TopicManager

  def handle(%SmartCity.Dataset{id: dataset_id}) do
    Logger.debug("#{__MODULE__}: Deleting Datatset: #{dataset_id}")

    with :ok <- DatasetHelper.deactivate_quantum_job(dataset_id),
         :ok <- DatasetHelper.retry_stopping_dataset(Reaper.Horde.Registry, dataset_id),
         :ok <- DatasetHelper.retry_stopping_dataset(Reaper.Cache.Registry, dataset_id),
         :ok <- TopicManager.delete_topic(dataset_id) do
      :ok
    end
  end
end

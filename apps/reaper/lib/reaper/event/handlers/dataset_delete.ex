defmodule Reaper.Event.Handlers.DatasetDelete do
  @moduledoc false

  require Logger

  alias Reaper.Event.Handlers.DatasetDisable
  alias Reaper.Topic.TopicManager

  def handle(%SmartCity.Dataset{id: dataset_id} = dataset) do
    Logger.debug("#{__MODULE__}: Deleting Datatset: #{dataset_id}")

    with :ok <- DatasetDisable.handle(dataset),
         :ok <- TopicManager.delete_topic(dataset_id) do
      :ok
    end
  end
end

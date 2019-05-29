defmodule Forklift.Datasets.DatasetHandler do
  @moduledoc """
  Subscribe to SmartCity Registry and pass new and updated datasets to a persistance/caching mechanism.
  """
  use SmartCity.Registry.MessageHandler
  alias Forklift.Datasets.DatasetRegistryServer
  alias Forklift.TopicManager

  def handle_dataset(%SmartCity.Dataset{technical: %{sourceType: "remote"}}) do
    :ok
  end

  def handle_dataset(%SmartCity.Dataset{} = dataset) do
    DatasetRegistryServer.send_message(dataset)
    TopicManager.create("transformed-#{dataset.id}")
  end
end

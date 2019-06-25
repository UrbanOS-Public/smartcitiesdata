defmodule Valkyrie.DatasetHandler do
  @moduledoc """
  MessageHandler to receive updated datasets and add to the cache
  """
  use SmartCity.Registry.MessageHandler
  alias SmartCity.Dataset

  def handle_dataset(%Dataset{technical: %{sourceType: "remote"}}) do
    :ok
  end

  def handle_dataset(dataset) do
    Valkyrie.TopicManager.create_and_subscribe("raw-#{dataset.id}")
    Valkyrie.Dataset.put(dataset)
  end
end

defmodule Valkyrie.DatasetHandler do
  @moduledoc """
  MessageHandler to receive updated datasets and add to the cache
  """
  use SmartCity.Registry.MessageHandler
  alias SmartCity.Dataset

  def handle_dataset(%Dataset{technical: %{sourceType: source_type}} = dataset)
      when source_type in ["ingest", "streaming"] do
    Valkyrie.TopicManager.create_and_subscribe(dataset, "raw-#{dataset.id}")
    # Valkyrie.Dataset.put(dataset)
  end

  def handle_dataset(_dataset) do
    :ok
  end
end

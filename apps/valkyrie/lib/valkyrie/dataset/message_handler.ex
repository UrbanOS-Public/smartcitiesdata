defmodule Valkyrie.Dataset.MessageHandler do
  @moduledoc """
  MessageHandler to receive updated datasets and add to the cache
  """
  use SmartCity.Registry.MessageHandler

  def handle_dataset(dataset) do
    Valkyrie.Dataset.put(dataset)
  end
end

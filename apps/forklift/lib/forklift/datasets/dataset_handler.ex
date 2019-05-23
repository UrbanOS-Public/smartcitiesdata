defmodule Forklift.Datasets.DatasetHandler do
  @moduledoc """
  Subscribe to SmartCity Registry and pass new and updated datasets to a persistance/caching mechanism.
  """
  use SmartCity.Registry.MessageHandler
  alias Forklift.Datasets.DatasetRegistryServer

  def handle_dataset(%SmartCity.Dataset{} = dataset) do
    DatasetRegistryServer.send_message(dataset)
  end
end

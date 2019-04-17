defmodule Forklift.DatasetHandler do
  @moduledoc false
  use SmartCity.Registry.MessageHandler
  alias Forklift.DatasetRegistryServer

  def handle_dataset(dataset) do
    DatasetRegistryServer.send_message(dataset)
  end
end

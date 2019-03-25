defmodule DiscoveryApi.Data.DatasetEventListener do
  @moduledoc false
  require Logger
  alias DiscoveryApi.Data.DatasetDetailsHandler
  alias DiscoveryApi.Data.ProjectOpenDataHandler
  use SmartCity.Registry.MessageHandler

  def handle_dataset(%SmartCity.Dataset{} = dataset) do
    Logger.debug(fn -> "Handling dataset: `#{dataset.technical.systemName}`" end)

    with {:ok, _result} <- DatasetDetailsHandler.process_dataset_details_event(dataset),
         ProjectOpenDataHandler.process_project_open_data_event(dataset) do
      Logger.debug(fn -> "Successfully handled message: `#{dataset.technical.systemName}`" end)
    else
      {:error, reason} -> log_error(dataset, reason)
    end
  end

  defp log_error(dataset, reason) do
    Logger.error("Unable to process message `#{inspect(dataset)}` : ERROR: #{inspect(reason)}")
  end
end

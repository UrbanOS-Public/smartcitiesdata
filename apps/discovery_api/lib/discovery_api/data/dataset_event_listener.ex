defmodule DiscoveryApi.Data.DatasetEventListener do
  @moduledoc false
  require Logger
  alias DiscoveryApi.Data.DatasetDetailsHandler
  alias DiscoveryApi.Data.ProjectOpenDataHandler
  alias SCOS.RegistryMessage

  def handle_message(%{value: value}) do
    Logger.debug(fn -> "Handling message: `#{value}`" end)

    with {:ok, registry_message} <- RegistryMessage.new(value),
         {:ok, _result} <- DatasetDetailsHandler.process_dataset_details_event(registry_message),
         ProjectOpenDataHandler.process_project_open_data_event(registry_message) do
      Logger.debug(fn -> "Successfully handled message: `#{value}`" end)
    else
      {:error, reason} -> log_error(value, reason)
    end
  end

  defp log_error(value, reason) do
    Logger.error("Unable to process message `#{value}` : ERROR: #{inspect(reason)}")
  end
end

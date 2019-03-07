defmodule DiscoveryApi.Data.DatasetEventListener do
  require Logger
  alias DiscoveryApi.Data.DatasetDetailsHandler
  alias SCOS.RegistryMessage

  def handle_message(%{value: value}) do
    Logger.debug("Handling message: `#{value}`")

    with {:ok, registry_message} <- RegistryMessage.new(value),
         {:ok, _result} <- DatasetDetailsHandler.process_dataset_details_event(registry_message) do
      Logger.debug("Successfully handled message: `#{value}`")
    else
      {:error, reason} -> log_error(value, reason)
    end
  end

  defp log_error(value, reason) do
    Logger.error("Unable to process message `#{value}` : ERROR: #{inspect(reason)}")
  end
end

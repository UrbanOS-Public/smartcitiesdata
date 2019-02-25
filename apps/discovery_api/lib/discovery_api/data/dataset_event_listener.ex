defmodule DiscoveryApi.Data.DatasetEventListener do
  require Logger
  alias DiscoveryApi.Data.DatasetDetailsHandler

  def handle_message(%{value: value}) do
    Logger.debug("Handling Message #{value}")

    {status, _} =
      Jason.decode!(value)
      |> DatasetDetailsHandler.process_dataset_details_event()

    Logger.debug("Handled Message #{value}")
    status
  end
end

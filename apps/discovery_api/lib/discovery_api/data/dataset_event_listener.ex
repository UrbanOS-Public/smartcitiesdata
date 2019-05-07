defmodule DiscoveryApi.Data.DatasetEventListener do
  @moduledoc false
  require Logger
  use SmartCity.Registry.MessageHandler

  alias DiscoveryApi.Data.{Mapper, Model, SystemNameCache}
  alias SmartCity.{Dataset, Organization}

  def handle_dataset(%Dataset{} = dataset) do
    Logger.debug(fn -> "Handling dataset: `#{dataset.technical.systemName}`" end)

    with {:ok, organization} <- Organization.get(dataset.technical.orgId),
         {:ok, _cached} <- SystemNameCache.put(dataset, organization),
         model <- Mapper.to_data_model(dataset, organization),
         {:ok, _result} <- Model.save(model) do
      Logger.debug(fn -> "Successfully handled message: `#{dataset.technical.systemName}`" end)
    else
      {:error, reason} ->
        Logger.error("Unable to process message `#{inspect(dataset)}` : ERROR: #{inspect(reason)}")
    end
  end
end

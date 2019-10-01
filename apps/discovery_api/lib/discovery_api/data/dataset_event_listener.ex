defmodule DiscoveryApi.Data.DatasetEventListener do
  @moduledoc """
  Subscribe to changes in datasets and update the local cache with any changes.
  """
  require Logger
  use SmartCity.Registry.MessageHandler

  alias DiscoveryApi.Data.{Mapper, Model, SystemNameCache}
  alias SmartCity.{Dataset, Organization}
  alias DiscoveryApiWeb.Plugs.ResponseCache

  def handle_dataset(%Dataset{} = dataset) do
    Logger.debug(fn -> "Handling dataset: `#{dataset.technical.systemName}`" end)

    with {:ok, organization} <- Organization.get(dataset.technical.orgId),
         {:ok, _cached} <- SystemNameCache.put(dataset, organization),
         model <- Mapper.to_data_model(dataset, organization),
         {:ok, _result} <- Model.save(model) do
      DiscoveryApi.Search.Storage.index(model)
      save_dataset_to_recommendation_engine(dataset)
      ResponseCache.invalidate()
      Logger.debug(fn -> "Successfully handled message: `#{dataset.technical.systemName}`" end)
    else
      {:error, reason} ->
        Logger.error("Unable to process message `#{inspect(dataset)}` : ERROR: #{inspect(reason)}")
    end
  end

  defp save_dataset_to_recommendation_engine(%Dataset{technical: %{private: false, schema: schema}} = dataset) when length(schema) > 0 do
    DiscoveryApi.RecommendationEngine.save(dataset)
  end

  defp save_dataset_to_recommendation_engine(_dataset) do
    :ok
  end
end

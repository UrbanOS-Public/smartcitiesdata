defmodule DiscoveryApi.EventHandler do
  @moduledoc "Event Handler for event stream"

  use Brook.Event.Handler
  import SmartCity.Event, only: [organization_update: 0, user_organization_associate: 0, dataset_update: 0]
  require Logger
  alias SmartCity.{Organization, UserOrganizationAssociate, Dataset}
  alias DiscoveryApi.Schemas.{Organizations, Users}
  alias DiscoveryApi.Data.{Mapper, Model, SystemNameCache}
  alias DiscoveryApiWeb.Plugs.ResponseCache

  def handle_event(%Brook.Event{type: organization_update(), data: %Organization{} = data}) do
    Organizations.create_or_update(data)
    :discard
  end

  def handle_event(%Brook.Event{type: user_organization_associate(), data: %UserOrganizationAssociate{} = association} = event) do
    case Users.associate_with_organization(association.user_id, association.org_id) do
      {:error, _} = error -> Logger.error("Unable to handle event: #{inspect(event)},\nerror: #{inspect(error)}")
      result -> result
    end

    :discard
  end

  # TODO: View state?
  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{} = dataset}) do
    Logger.debug(fn -> "Handling dataset: `#{dataset.technical.systemName}`" end)

    with {:ok, organization} <- DiscoveryApi.Schemas.Organizations.get_organization(dataset.technical.orgId),
         {:ok, _cached} <- SystemNameCache.put(dataset, organization),
         model <- Mapper.to_data_model(dataset, organization),
         {:ok, _result} <- Model.save(model) do
      DiscoveryApi.Search.Storage.index(model)
      save_dataset_to_recommendation_engine(dataset)
      ResponseCache.invalidate()
      Logger.debug(fn -> "Successfully handled message: `#{dataset.technical.systemName}`" end)

      :discard
    else
      {:error, reason} ->
        Logger.error("Unable to process message `#{inspect(dataset)}` : ERROR: #{inspect(reason)}")
        :discard
    end
  end

  defp save_dataset_to_recommendation_engine(%Dataset{technical: %{private: false, schema: schema}} = dataset) when length(schema) > 0 do
    DiscoveryApi.RecommendationEngine.save(dataset)
  end

  defp save_dataset_to_recommendation_engine(_dataset), do: :ok
end

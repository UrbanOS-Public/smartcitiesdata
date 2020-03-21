defmodule DiscoveryApi.EventHandler do
  @moduledoc "Event Handler for event stream"

  use Brook.Event.Handler

  import SmartCity.Event,
    only: [organization_update: 0, user_organization_associate: 0, dataset_update: 0, data_write_complete: 0, dataset_delete: 0]

  require Logger
  alias SmartCity.{Organization, UserOrganizationAssociate, Dataset}
  alias DiscoveryApi.RecommendationEngine
  alias DiscoveryApi.Schemas.{Organizations, Users}
  alias DiscoveryApi.Data.{Mapper, Model, SystemNameCache}
  alias DiscoveryApi.Stats.StatsCalculator
  alias DiscoveryApi.Search.Storage
  alias DiscoveryApiWeb.Plugs.ResponseCache
  alias DiscoveryApi.Services.DataJsonService

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

  def handle_event(%Brook.Event{type: data_write_complete(), data: %SmartCity.DataWriteComplete{id: id, timestamp: timestamp}}) do
    Logger.debug(fn -> "Handling write complete for #{inspect(id)}" end)

    case Brook.get(DiscoveryApi.instance(), :models, id) do
      {:ok, nil} ->
        Logger.debug(fn -> "Discarded write complete for non-existent dataset #{inspect(id)}" end)
        :discard

      {:ok, _} ->
        merge(:models, id, %{id: id, lastUpdatedDate: timestamp})

      error ->
        Logger.debug(fn -> "Discarded write complete for dataset #{inspect(id)} due to #{inspect(error)}" end)
        :discard
    end
  end

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{} = dataset}) do
    Logger.debug(fn -> "Handling dataset: `#{dataset.technical.systemName}`" end)

    with {:ok, organization} <- DiscoveryApi.Schemas.Organizations.get_organization(dataset.technical.orgId),
         {:ok, _cached} <- SystemNameCache.put(dataset.id, organization.name, dataset.technical.dataName),
         model <- Mapper.to_data_model(dataset, organization) do
      DiscoveryApi.Search.Storage.index(model)
      save_dataset_to_recommendation_engine(dataset)
      Logger.debug(fn -> "Successfully handled message: `#{dataset.technical.systemName}`" end)
      merge(:models, model.id, model)
      ResponseCache.invalidate()
      DataJsonService.delete_data_json()

      :discard
    else
      {:error, reason} ->
        Logger.error("Unable to process message `#{inspect(dataset)}` : ERROR: #{inspect(reason)}")
        :discard
    end
  end

  def handle_event(%Brook.Event{type: dataset_delete(), data: %Dataset{} = dataset}) do
    RecommendationEngine.delete(dataset.id)
    SystemNameCache.delete(dataset.technical.orgName, dataset.technical.dataName)
    Storage.delete(dataset)
    StatsCalculator.delete_completeness(dataset.id)
    Model.delete(dataset.id)
    ResponseCache.invalidate()
    DataJsonService.delete_data_json()
    Logger.debug("#{__MODULE__}: Deleted dataset: #{dataset.id}")

    :discard
  rescue
    error ->
      Logger.error("#{__MODULE__}: Failed to delete dataset: #{dataset.id}, Reason: #{inspect(error)}")
      :discard
  end

  defp save_dataset_to_recommendation_engine(%Dataset{technical: %{private: false, schema: schema}} = dataset) when length(schema) > 0 do
    RecommendationEngine.save(dataset)
  end

  defp save_dataset_to_recommendation_engine(_dataset), do: :ok
end

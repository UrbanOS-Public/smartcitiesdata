defmodule DiscoveryApi.Event.EventHandler do
  @moduledoc "Event Handler for event stream"

  use Brook.Event.Handler
  alias DiscoveryApi.Data.TableInfoCache

  import SmartCity.Event,
    only: [
      organization_update: 0,
      user_organization_associate: 0,
      user_organization_disassociate: 0,
      dataset_update: 0,
      data_write_complete: 0,
      dataset_delete: 0,
      dataset_query: 0,
      user_login: 0,
      dataset_access_group_associate: 0,
      dataset_access_group_disassociate: 0
    ]

  require Logger
  alias SmartCity.{Organization, UserOrganizationAssociate, UserOrganizationDisassociate, Dataset, DatasetAccessGroupRelation}
  alias DiscoveryApi.RecommendationEngine
  alias DiscoveryApi.Schemas.{Organizations, Users}
  alias DiscoveryApi.Data.{Mapper, Model, SystemNameCache}
  alias DiscoveryApi.Stats.StatsCalculator
  alias DiscoveryApiWeb.Plugs.ResponseCache
  alias DiscoveryApi.Services.DataJsonService
  alias DiscoveryApi.Search.Elasticsearch
  alias DiscoveryApi.Services.MetricsService

  @instance_name DiscoveryApi.instance_name()

  def handle_event(%Brook.Event{type: organization_update(), data: %Organization{} = data, author: author}) do
    organization_update()
    |> add_event_count(author, data.id)

    Organizations.create_or_update(data)
    :discard
  end

  def handle_event(
        %Brook.Event{type: user_organization_associate(), data: %UserOrganizationAssociate{} = association, author: author} = event
      ) do
    user_organization_associate()
    |> add_event_count(author, nil)

    case Users.associate_with_organization(association.subject_id, association.org_id) do
      {:error, _} = error -> Logger.error("Unable to handle event: #{inspect(event)},\nerror: #{inspect(error)}")
      result -> result
    end

    # This caches some tables that a user can access. This event can change that.
    TableInfoCache.invalidate()

    :discard
  end

  def handle_event(
        %Brook.Event{type: user_organization_disassociate(), data: %UserOrganizationDisassociate{} = disassociation, author: author} = event
      ) do
    user_organization_disassociate()
    |> add_event_count(author, nil)

    case Users.disassociate_with_organization(disassociation.subject_id, disassociation.org_id) do
      {:error, _} = error -> Logger.error("Unable to handle event: #{inspect(event)},\nerror: #{inspect(error)}")
      result -> result
    end

    # This caches some tables that a user can access. This event can change that.
    TableInfoCache.invalidate()

    :discard
  end

  def handle_event(%Brook.Event{
        type: data_write_complete(),
        data: %SmartCity.DataWriteComplete{id: id, timestamp: timestamp},
        author: author
      }) do
    Logger.debug(fn -> "Handling write complete for #{inspect(id)}" end)

    data_write_complete()
    |> add_event_count(author, nil)

    case Brook.get(@instance_name, :models, id) do
      {:ok, nil} ->
        Logger.debug(fn -> "Discarded write complete for non-existent dataset #{inspect(id)}" end)
        :discard

      {:ok, model} ->
        model
        |> Map.put(:lastUpdatedDate, timestamp)
        |> Elasticsearch.Document.update()

        merge(:models, id, %{id: id, lastUpdatedDate: timestamp})

      error ->
        Logger.debug(fn -> "Discarded write complete for dataset #{inspect(id)} due to #{inspect(error)}" end)
        :discard
    end
  end

  def handle_event(%Brook.Event{type: dataset_update(), author: author, data: %Dataset{} = dataset}) do
    Logger.debug(fn -> "Handling dataset: `#{dataset.technical.systemName}`" end)

    dataset_update()
    |> add_event_count(author, dataset.id)

    Task.start(fn -> add_dataset_count() end)

    with {:ok, organization} <- DiscoveryApi.Schemas.Organizations.get_organization(dataset.technical.orgId),
         {:ok, _cached} <- SystemNameCache.put(dataset.id, organization.name, dataset.technical.dataName),
         {:ok, model} <- Mapper.to_data_model(dataset, organization) do
      Elasticsearch.Document.update(model)
      save_dataset_to_recommendation_engine(dataset)
      Logger.debug(fn -> "Successfully handled message: `#{dataset.technical.systemName}`" end)
      merge(:models, model.id, model)
      clear_caches()

      :discard
    else
      {:error, reason} ->
        Logger.error("Unable to process message `#{inspect(dataset)}` from `#{inspect(author)}` : ERROR: #{inspect(reason)}")
        :discard
    end
  end

  def handle_event(%Brook.Event{type: dataset_access_group_associate(), author: author, data: %DatasetAccessGroupRelation{} = relation}) do
    Logger.debug(fn ->
      "Handling dataset-access-group association: `Dataset: #{relation.dataset_id} Access Group: #{relation.access_group_id}`"
    end)

    dataset_access_group_associate()
    |> add_event_count(author, relation.dataset_id)

    with {:ok, dataset} <- Brook.get(@instance_name, :models, relation.dataset_id),
         model <- Mapper.add_access_group(dataset, relation.access_group_id) do
      Elasticsearch.Document.update(model)

      Logger.debug(fn ->
        "Successfully handled dataset-access-group association message: `Dataset: #{relation.dataset_id} Access Group: #{
          relation.access_group_id
        }`"
      end)

      merge(:models, model.id, model)
      clear_caches()

      :discard
    else
      {:error, reason} ->
        Logger.error("Unable to process message `#{inspect(relation)}` from `#{inspect(author)}` : ERROR: #{inspect(reason)}")
        :discard
    end
  end

  def handle_event(%Brook.Event{type: dataset_access_group_disassociate(), author: author, data: %DatasetAccessGroupRelation{} = relation}) do
    Logger.debug(fn ->
      "Handling dataset-access-group disassociation: `Dataset: #{relation.dataset_id} Access Group: #{relation.access_group_id}`"
    end)

    dataset_access_group_disassociate()
    |> add_event_count(author, relation.dataset_id)

    dataset_result = Brook.get(@instance_name, :models, relation.dataset_id)

    case dataset_result do
      {:ok, nil} -> :discard
      {:ok, _} -> handle_non_nil_dataset(relation, author)
    end
  end

  defp handle_non_nil_dataset(relation, author) do
    with {:ok, dataset} <- Brook.get(@instance_name, :models, relation.dataset_id),
         model <- Mapper.remove_access_group(dataset, relation.access_group_id) do
      Elasticsearch.Document.update(model)

      Logger.debug(fn ->
        "Successfully handled dataset-access-group disassociation message: `Dataset: #{relation.dataset_id} Access Group: #{
          relation.access_group_id
        }`"
      end)

      merge(:models, model.id, model)
      clear_caches()

      :discard
    else
      {:error, reason} ->
        Logger.error("Unable to process message `#{inspect(relation)}` from `#{inspect(author)}` : ERROR: #{inspect(reason)}")
        :discard
    end
  end

  def handle_event(%Brook.Event{type: dataset_query(), data: dataset_id, author: author, create_ts: timestamp}) do
    dataset_query()
    |> add_event_count(author, dataset_id)

    MetricsService.record_api_hit(dataset_query(), dataset_id)
    Logger.debug(fn -> "Successfully recorded api hit for dataset: `#{dataset_id}` at #{timestamp}" end)

    clear_caches()
    :discard
  end

  def handle_event(%Brook.Event{type: dataset_delete(), data: %Dataset{} = dataset, author: author}) do
    dataset_delete()
    |> add_event_count(author, dataset.id)

    Task.start(fn -> add_dataset_count() end)
    RecommendationEngine.delete(dataset.id)
    SystemNameCache.delete(dataset.technical.orgName, dataset.technical.dataName)
    Elasticsearch.Document.delete(dataset.id)
    StatsCalculator.delete_completeness(dataset.id)
    Model.delete(dataset.id)
    clear_caches()
    Logger.debug("#{__MODULE__}: Deleted dataset: #{dataset.id}")

    :discard
  rescue
    error ->
      Logger.error("#{__MODULE__}: Failed to delete dataset: #{dataset.id}, Reason: #{inspect(error)}")
      :discard
  end

  def handle_event(%Brook.Event{type: user_login(), data: %{subject_id: subject_id, email: email, name: name}, author: author}) do
    user_login()
    |> add_event_count(author, nil)

    create_user_if_not_exists(subject_id, email, name)
  end

  defp create_user_if_not_exists(subject_id, email, name) do
    case Users.get_user(subject_id, :subject_id) do
      {:ok, _user} ->
        :ok

      _ ->
        Users.create(%{subject_id: subject_id, email: email, name: name})
        :ok
    end
  end

  defp clear_caches() do
    ResponseCache.invalidate()
    DataJsonService.delete_data_json()
    TableInfoCache.invalidate()
  end

  defp save_dataset_to_recommendation_engine(%Dataset{technical: %{private: false, schema: schema}} = dataset) when length(schema) > 0 do
    RecommendationEngine.save(dataset)
  end

  defp save_dataset_to_recommendation_engine(_dataset), do: :ok

  defp add_event_count(event_type, author, dataset_id) do
    [
      app: "discovery_api",
      author: author,
      dataset_id: dataset_id,
      event_type: event_type
    ]
    |> TelemetryEvent.add_event_metrics([:events_handled])
  end

  defp add_dataset_count() do
    # This will sleep for 5 seconds, before getting most recently updated dataset count by the Brook Event
    Process.sleep(5_000)

    count =
      Brook.get_all_values!(@instance_name, :models)
      |> Enum.count()

    [
      app: "discovery_api"
    ]
    |> TelemetryEvent.add_event_metrics([:dataset_total], value: %{count: count})
  end
end

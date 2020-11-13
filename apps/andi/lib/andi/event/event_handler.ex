defmodule Andi.Event.EventHandler do
  @moduledoc "Event Handler for event stream"
  use Brook.Event.Handler
  require Logger

  import SmartCity.Event,
    only: [
      dataset_update: 0,
      organization_update: 0,
      user_organization_associate: 0,
      data_ingest_end: 0,
      dataset_delete: 0,
      dataset_harvest_start: 0,
      dataset_harvest_end: 0
    ]

  alias SmartCity.{Dataset, Organization}
  alias SmartCity.UserOrganizationAssociate

  alias Andi.Services.DatasetStore
  alias Andi.Services.OrgStore
  alias Andi.Harvest.Harvester

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Organizations

  @instance_name Andi.instance_name()

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{} = data, author: author}) do
    dataset_update()
    |> add_event_count(author, data.id)

    Andi.DatasetCache.add_dataset_info(data)

    Task.start(fn -> add_dataset_count() end)
    Datasets.update_ingested_time(data.id, DateTime.utc_now())

    Datasets.update(data)
    DatasetStore.update(data)
  end

  def handle_event(%Brook.Event{type: organization_update(), data: %Organization{} = data, author: author}) do
    organization_update()
    |> add_event_count(author, data.id)

    data_harvest_event(data)

    Organizations.update(data)
    OrgStore.update(data)
  end

  def handle_event(%Brook.Event{
        type: user_organization_associate(),
        data: %UserOrganizationAssociate{user_id: user_id, org_id: org_id},
        author: author
      }) do
    user_organization_associate()
    |> add_event_count(author, nil)

    merge(:org_to_users, org_id, &add_to_set(&1, user_id))
    merge(:user_to_orgs, user_id, &add_to_set(&1, org_id))
  end

  def handle_event(%Brook.Event{type: dataset_harvest_start(), data: %Organization{} = data, author: author}) do
    dataset_harvest_start()
    |> add_event_count(author, data.id)

    Task.start_link(Harvester, :start_harvesting, [data])

    :discard
  end

  def handle_event(%Brook.Event{type: dataset_harvest_end(), data: data}) do
    Organizations.update_harvested_dataset(data)
    :discard
  end

  def handle_event(%Brook.Event{type: "migration:modified_date:start", author: author}) do
    "migration:modified_date:start"
    |> add_event_count(author, nil)

    Andi.Migration.ModifiedDateMigration.do_migration()
    {:create, :migration, "modified_date_migration_completed", true}
  end

  def handle_event(%Brook.Event{type: data_ingest_end(), data: %Dataset{id: id}, create_ts: create_ts, author: author}) do
    data_ingest_end()
    |> add_event_count(author, id)

    {:create, :ingested_time, id, %{"id" => id, "ingested_time" => create_ts}}
  end

  def handle_event(%Brook.Event{
        type: dataset_delete(),
        data: %Dataset{} = dataset,
        author: author
      }) do
    dataset_delete()
    |> add_event_count(author, dataset.id)

    Task.start(fn -> add_dataset_count() end)
    Datasets.delete(dataset.id)
    DatasetStore.delete(dataset.id)
  end

  defp add_to_set(nil, id), do: MapSet.new([id])
  defp add_to_set(set, id), do: MapSet.put(set, id)

  defp add_event_count(event_type, author, dataset_id) do
    [
      app: "andi",
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
      DatasetStore.get_all!()
      |> Enum.count()

    [
      app: "andi"
    ]
    |> TelemetryEvent.add_event_metrics([:dataset_total], value: %{count: count})
  end

  defp data_harvest_event(org) do
    case org.dataJsonUrl do
      nil -> :ok
      _ -> Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, org)
    end
  end
end

defmodule Andi.EventHandler do
  @moduledoc "Event Handler for event stream"
  use Brook.Event.Handler
  require Logger

  import SmartCity.Event,
    only: [dataset_update: 0, organization_update: 0, user_organization_associate: 0, data_ingest_end: 0, dataset_delete: 0]

  alias SmartCity.{Dataset, Organization}
  alias SmartCity.UserOrganizationAssociate

  alias Andi.Services.DatasetStore

  alias Andi.InputSchemas.Datasets
  alias Andi.TelemetryHelper

  @ingested_time_topic "ingested_time_topic"

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{} = data}) do
    TelemetryHelper.add_event_count("dataset_update")
    Datasets.update(data)
    DatasetStore.update(data)
  end

  def handle_event(%Brook.Event{type: organization_update(), data: %Organization{} = data}) do
    TelemetryHelper.add_event_count("organization_update")
    {:merge, :org, data.id, data}
  end

  def handle_event(%Brook.Event{
        type: user_organization_associate(),
        data: %UserOrganizationAssociate{user_id: user_id, org_id: org_id}
      }) do
    TelemetryHelper.add_event_count("user_organization_associate")
    merge(:org_to_users, org_id, &add_to_set(&1, user_id))
    merge(:user_to_orgs, user_id, &add_to_set(&1, org_id))
  end

  def handle_event(%Brook.Event{type: "migration:modified_date:start"}) do
    TelemetryHelper.add_event_count("migration:modified_date:start")
    Andi.Migration.ModifiedDateMigration.do_migration()
    {:create, :migration, "modified_date_migration_completed", true}
  end

  def handle_event(%Brook.Event{type: data_ingest_end(), data: %Dataset{id: id}, create_ts: create_ts}) do
    TelemetryHelper.add_event_count("data_ingest_end")

    # Brook converts all maps to string keys when it retrieves a value from its state, even if they're inserted as atom keys. For that reason, make sure to insert as string keys so that we're consistent.
    Datasets.update_ingested_time(id, create_ts)

    AndiWeb.Endpoint.broadcast!(@ingested_time_topic, "ingested_time_update", %{
      "id" => id,
      "ingested_time" => create_ts
    })

    {:create, :ingested_time, id, %{"id" => id, "ingested_time" => create_ts}}
  end

  def handle_event(%Brook.Event{
        type: dataset_delete(),
        data: %Dataset{} = dataset
      }) do
    TelemetryHelper.add_event_count("dataset_delete")
    Datasets.delete(dataset.id)
    DatasetStore.delete(dataset.id)
  end

  defp add_to_set(nil, id), do: MapSet.new([id])
  defp add_to_set(set, id), do: MapSet.put(set, id)
end

defmodule Andi.EventHandler do
  @moduledoc "Event Handler for event stream"
  use Brook.Event.Handler
  require Logger

  import SmartCity.Event,
    only: [dataset_update: 0, organization_update: 0, user_organization_associate: 0, data_ingest_end: 0]

  alias SmartCity.{Dataset, Organization}
  alias SmartCity.UserOrganizationAssociate

  alias Andi.DatasetCache

  @ingested_time_topic "ingested_time_topic"

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{} = data}) do
    DatasetCache.put(data)
    {:merge, :dataset, data.id, data}
  end

  def handle_event(%Brook.Event{type: organization_update(), data: %Organization{} = data}) do
    {:merge, :org, data.id, data}
  end

  def handle_event(%Brook.Event{
        type: user_organization_associate(),
        data: %UserOrganizationAssociate{user_id: user_id, org_id: org_id}
      }) do
    merge(:org_to_users, org_id, &add_to_set(&1, user_id))
    merge(:user_to_orgs, user_id, &add_to_set(&1, org_id))
  end

  def handle_event(%Brook.Event{type: "migration:modified_date:start"}) do
    Andi.Migration.ModifiedDateMigration.do_migration()
    {:create, :migration, "modified_date_migration_completed", true}
  end

  def handle_event(%Brook.Event{type: data_ingest_end(), data: %Dataset{id: id}, create_ts: create_ts}) do
    # Brook converts all maps to string keys, so we must make sure that's what we're expecting
    # DatasetCache.put(%{"id" => id, "ingested_time" => create_ts})

    AndiWeb.Endpoint.broadcast!(@ingested_time_topic, "ingested_time_update", %{
      "id" => id,
      "ingested_time" => create_ts
    })

    {:create, :ingested_time, id, %{"id" => id, "ingested_time" => create_ts}}
  end

  def handle_test_event() do
    AndiWeb.Endpoint.broadcast!(@ingested_time_topic, "ingested_time_update", %{
      "id" => "id",
      "ingested_time" => "create_ts"
    })
  end

  defp add_to_set(nil, id), do: MapSet.new([id])
  defp add_to_set(set, id), do: MapSet.put(set, id)
end

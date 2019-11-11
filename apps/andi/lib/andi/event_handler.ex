defmodule Andi.EventHandler do
  @moduledoc "Event Handler for event stream"
  use Brook.Event.Handler
  require Logger

  import SmartCity.Event, only: [dataset_update: 0, organization_update: 0, user_organization_associate: 0]

  alias SmartCity.{Dataset, Organization}
  alias SmartCity.UserOrganizationAssociate

  alias Andi.DatasetCache

  def handle_event(%Brook.Event{type: dataset_update(), data: %Dataset{} = data}) do
    DatasetCache.put_dataset(data)
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

  def handle_event(%Brook.Event{type: "migration:modified_dates"}) do
    Andi.ModifiedDateMigration.do_migration()
    {:create, :migration, "modified_date_migration_completed", true}
  end

  defp add_to_set(nil, id), do: MapSet.new([id])
  defp add_to_set(set, id), do: MapSet.put(set, id)
end

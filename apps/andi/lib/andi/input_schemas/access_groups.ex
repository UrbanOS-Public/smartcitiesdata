defmodule Andi.InputSchemas.AccessGroups do
  @moduledoc false

  alias Andi.Repo
  alias Ecto.Changeset
  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.StructTools

  import Ecto.Query, only: [from: 2]

  require Logger

  def get(id), do: Repo.get(AccessGroup, id)

  def get_all(), do: Repo.all(AccessGroup)

  def create() do
    access_group_name = "New Access Group - #{Date.utc_today()}"

    changeset =
      AccessGroup.changeset(%{
        id: UUID.uuid4(),
        name: access_group_name
      })

    {:ok, new_changeset} = save(changeset)
    new_changeset
  end

  def delete(access_group_id) do
    Repo.delete(%AccessGroup{id: access_group_id})
  rescue
    _e in Ecto.StaleEntryError ->
      {:error, "attempted to remove an access group (id: #{access_group_id}) that does not exist."}
  end

  def update(%SmartCity.AccessGroup{} = smrt_access_group) do
    andi_access_group =
      case get(smrt_access_group.id) do
        nil -> %AccessGroup{}
        access_group -> access_group
      end

    update(andi_access_group, smrt_access_group)
  end

  def update(%AccessGroup{} = access_group) do
    original_access_group =
      case get(access_group.id) do
        nil -> %AccessGroup{}
        acc_group -> acc_group
      end

    update(original_access_group, access_group)
  end

  def update(%AccessGroup{} = from_access_group, changes) do
    changes_as_map = StructTools.to_map(changes)

    AccessGroup.changeset(from_access_group, changes_as_map)
    |> save()
  end

  def save(%Changeset{} = changeset) do
    Repo.insert_or_update(changeset)
  end
end

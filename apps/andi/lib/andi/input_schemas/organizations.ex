defmodule Andi.InputSchemas.Organizations do
  @moduledoc false

  alias Andi.Repo
  alias Ecto.Changeset
  alias Andi.InputSchemas.Datasets.HarvestedDatasets
  alias Andi.InputSchemas.Organization
  alias Andi.InputSchemas.StructTools

  import Ecto.Query, only: [from: 2]

  require Logger

  def get(id), do: Repo.get(Organization, id)

  def get_all(), do: Repo.all(Organization)

  def get_harvested_dataset(id) do
    Repo.get(HarvestedDatasets, id)
    |> HarvestedDatasets.preload()
  end

  def get_all_harvested_datasets(org_id) do
    query =
      from(harvested_dataset in HarvestedDatasets,
        where: harvested_dataset.orgId == ^org_id,
        select: harvested_dataset
      )

    Repo.all(query)
  end

  def update(%SmartCity.Organization{} = smrt_org) do
    andi_org =
      case get(smrt_org.id) do
        nil -> %Organization{}
        organization -> organization
      end

    update(andi_org, smrt_org)
  end

  def update(%Organization{} = org) do
    original_org =
      case get(org.id) do
        nil -> %Organization{}
        organization -> organization
      end

    update(original_org, org)
  end

  def update(%Organization{} = from_org, changes) do
    changes_as_map = StructTools.to_map(changes)

    Organization.changeset(from_org, changes_as_map)
    |> save()
  end

  def save(%Changeset{} = changeset) do
    Repo.insert_or_update(changeset)
  end

  def update_harvested_dataset(harvested_dataset) do
    changes = harvested_dataset |> AtomicMap.convert(safe: false, underscore: false)

    HarvestedDatasets.changeset(changes)
    |> save()
  end
end

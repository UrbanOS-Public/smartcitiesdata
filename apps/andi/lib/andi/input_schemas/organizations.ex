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

  def get_harvested_dataset(dataset_id) do
    Repo.get_by(HarvestedDatasets, datasetId: dataset_id)
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

  def create() do
    org_title = "New Organization - #{Date.utc_today()}"

    changeset =
      Organization.changeset(%{
        id: UUID.uuid4(),
        orgTitle: org_title,
        orgName: org_title_to_org_name(org_title),
        description: "New Organization description"
      })

    {:ok, new_changeset} = save(changeset)
    new_changeset
  end

  def delete_harvested_dataset(dataset_id) do
    case get_harvested_dataset(dataset_id) do
      %{id: id} -> Repo.delete(%HarvestedDatasets{id: id})
      _ -> Logger.info("Unable to delete dataset: #{dataset_id} from harvested datasets")
    end
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

  def update_harvested_dataset(harvested_dataset, changes) do
    changes = changes |> AtomicMap.convert(safe: false, underscore: false)

    HarvestedDatasets.changeset(harvested_dataset, changes)
    |> save()
  end

  def update_harvested_dataset(harvested_dataset) do
    changes = harvested_dataset |> AtomicMap.convert(safe: false, underscore: false)

    HarvestedDatasets.changeset(changes)
    |> save()
  end

  def update_harvested_dataset_include(dataset_id, val) when is_boolean(val) do
    case get_harvested_dataset(dataset_id) do
      nil -> Logger.error("Harvested dataset #{dataset_id} doesn't exist")
      dataset -> update_harvested_dataset(dataset, %{include: val})
    end
  end

  def is_unique?(id, nil) do
    false
  end

  def is_unique?(id, org_name) do
    from(org in Andi.InputSchemas.Organization,
      where: org.orgName == ^org_name and org.id != ^id
    )
    |> Repo.all()
    |> Enum.empty?()
  end

  def org_title_to_org_name(org_title) do
    org_title
    |> String.replace(" ", "_", global: true)
    |> String.replace(~r/[^[:alnum:]_]/, "", global: true)
    |> String.replace(~r/_+/, "_", global: true)
    |> String.downcase()
  end
end

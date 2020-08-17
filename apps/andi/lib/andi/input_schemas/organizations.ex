defmodule Andi.InputSchemas.Organizations do
  @moduledoc false

  alias Andi.Repo
  alias Ecto.Changeset
  alias Andi.InputSchemas.Datasets.HarvestedDatasets
  alias Andi.InputSchemas.Organization

  import Ecto.Query, only: [from: 2]

  require Logger

  def get(id), do: Repo.get(Organization, id)

  def get_all(), do: Repo.all(Organization)

  def get_harvested_dataset(id) do
    Repo.get(HarvestedDatasets, id)
    |> HarvestedDatasets.preload()
  end

  def get_all_harvested_datasets() do
    query =
      from(harvested_dataset in HarvestedDatasets,
        select: harvested_dataset
      )

    Repo.all(query)
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

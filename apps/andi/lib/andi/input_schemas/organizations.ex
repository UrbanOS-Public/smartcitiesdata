defmodule Andi.InputSchemas.Organizations do
  @moduledoc false
  alias Andi.InputSchemas.Datasets.HarvestedDatasets
  alias Andi.Repo
  alias Andi.InputSchemas.StructTools
  alias Ecto.Changeset

  import Ecto.Query, only: [from: 2]

  require Logger

  def get(id) do
    Repo.get(HarvestedDatasets, id)
    |> HarvestedDatasets.preload()
  end

  def get_harvested_dataset(sourceId) do
    Repo.get_by(HarvestedDatasets, sourceId: sourceId)
    |> HarvestedDatasets.preload()
  end

  def get_all() do
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

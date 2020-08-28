defmodule Andi.Repo.Migrations.CreateUniqueConstraintDatasetId do
  use Ecto.Migration

  def change do
    create unique_index(:harvested_datasets, [:datasetId])
  end
end

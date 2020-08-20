defmodule Andi.Repo.Migrations.AddDatasetId do
  use Ecto.Migration

  def change do
    alter table(:harvested_datasets) do
      add :datasetId, :string
    end
  end
end

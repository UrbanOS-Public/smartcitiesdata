defmodule Andi.Repo.Migrations.AddHarvestedDatasetsTable do
  use Ecto.Migration

  def change do
    create table(:harvested_datasets, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :orgId, :string
      add :sourceId, :string
      add :systemId, :string
      add :source, :string
      add :modifiedDate, :utc_datetime
      add :include, :boolean
    end
  end
end

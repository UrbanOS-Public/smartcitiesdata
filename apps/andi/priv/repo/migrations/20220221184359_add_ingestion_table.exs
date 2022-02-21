defmodule Andi.Repo.Migrations.AddIngestionTable do
  use Ecto.Migration

  def change do
    create table(:ingestions, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :allow_duplicates, :boolean
      add :cadence, :string
      add :schema, {:array, :map}, default: []
      add :extractSteps, {:array, :map}, default: []
      add :targetDataset, references(:datasets, type: :string, on_delete: :delete_all), null: false
      add :sourceFormat, :string
      add :topLevelSelector, :string
    end

    alter table(:extract_step) do
      add :ingestion_id, references(:ingestions, type: :uuid, on_delete: :delete_all)
    end

    alter table(:data_dictionary) do
      add :ingestion_id, references(:ingestions, type: :uuid, on_delete: :delete_all)
    end

  end
end

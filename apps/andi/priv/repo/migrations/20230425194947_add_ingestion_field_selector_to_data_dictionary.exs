defmodule Andi.Repo.Migrations.AddIngestionFieldSelector do
  use Ecto.Migration

  def change do
    alter table(:data_dictionary) do
      add :ingestion_field_selector, :string
      add :ingestion_field_sync, :boolean
    end
  end
end

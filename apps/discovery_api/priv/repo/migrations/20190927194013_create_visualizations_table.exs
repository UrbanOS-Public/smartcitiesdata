defmodule DiscoveryApi.Repo.Migrations.CreateVisualizationsTable do
  use Ecto.Migration

  def change do
    create table(:visualizations) do
      add(:public_id, :string, null: false)
      add(:query, :string, null: false)
      add(:title, :string, null: false)
      add :owner_id, references(:users), null: false

      timestamps()
    end

    create unique_index(:visualizations, [:public_id])
  end
end

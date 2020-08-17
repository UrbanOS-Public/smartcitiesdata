defmodule Andi.Repo.Migrations.CreateUniqueConstraintSourceId do
  use Ecto.Migration

  def change do
    create unique_index(:harvested_datasets, [:sourceId])
  end
end

defmodule Andi.Repo.Migrations.CreateIndexDatasetId do
  use Ecto.Migration

  def change do
    create index(:event_log, [:dataset_id])
  end
end

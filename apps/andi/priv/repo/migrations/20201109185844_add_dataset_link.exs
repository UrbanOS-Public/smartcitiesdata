defmodule Andi.Repo.Migrations.AddDatasetLink do
  use Ecto.Migration

  def change do
    alter table(:datasets) do
      add :datasetLink, :string
    end
  end
end

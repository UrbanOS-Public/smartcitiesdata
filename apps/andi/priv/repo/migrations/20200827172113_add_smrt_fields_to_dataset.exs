defmodule Andi.Repo.Migrations.AddSmrtFieldsToDataset do
  use Ecto.Migration

  def change do
    alter table(:datasets) do
      add :version, :string
    end
  end
end

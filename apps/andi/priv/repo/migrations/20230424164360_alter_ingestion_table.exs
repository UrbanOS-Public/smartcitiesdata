defmodule Andi.Repo.Migrations.AlterIngestionTable do
  use Ecto.Migration

  def change do
    alter table(:ingestions) do
      remove :targetDataset
      add :targetDatasets, {:array, :string}, default: []
    end
  end
end

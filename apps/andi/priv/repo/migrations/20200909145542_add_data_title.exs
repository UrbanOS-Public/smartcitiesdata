defmodule Andi.Repo.Migrations.AddDataTitle do
  use Ecto.Migration

  def change do
    alter table(:harvested_datasets) do
      add :dataTitle, :string
    end
  end
end

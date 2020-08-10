defmodule Andi.Repo.Migrations.AddHarvestedDatasets do
  use Ecto.Migration

  def change do
    alter table(:datasets) do
      add :harvestedDataset, :boolean
    end
  end
end

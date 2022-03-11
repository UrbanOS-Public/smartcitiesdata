defmodule Andi.Repo.Migrations.AddIngestionName do
  use Ecto.Migration

  def change do
    alter table(:ingestions) do
      add :name, :string
    end

  end
end

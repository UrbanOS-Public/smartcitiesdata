defmodule Andi.Repo.Migrations.AddDefaultToDataDictionary do
  use Ecto.Migration

  def change do
    alter table(:data_dictionary) do
      add :default, :map
    end

  end
end

defmodule Andi.Repo.Migrations.StoreOffsetForDefault do
  use Ecto.Migration

  def change do
    alter table(:data_dictionary) do
      remove :default
      add :default_offset, :integer
      add :use_default, :boolean
    end
  end
end

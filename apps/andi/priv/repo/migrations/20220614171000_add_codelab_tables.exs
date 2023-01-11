defmodule Andi.Repo.Migrations.CreateCodelabTables do
  use Ecto.Migration

  # This migration is just for tests. It facilitates changeset testing in the codelabs.
  def change do
    create table(:person, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)
      add :name, :string
      add :age, :integer
      add :address, {:array, :map}, default: []
    end

    create table(:address, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :street, :string
      add :person_id, references(:person, type: :uuid, on_delete: :delete_all)
    end
  end
end

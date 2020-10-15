defmodule Andi.Repo.Migrations.AddUserIdToDataset do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :subject_id, :string, null: false
      add :email, :string, null: false
    end

    create unique_index(:users, [:subject_id])

    alter table(:datasets) do
      add :owner_id, references(:users, type: :uuid), null: true
    end
  end
end

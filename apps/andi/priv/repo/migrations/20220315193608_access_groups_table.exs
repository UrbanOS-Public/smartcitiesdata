defmodule Andi.Repo.Migrations.AccessGroupsTable do
  use Ecto.Migration

  def change do
      create table(:access_groups, primary_key: false) do
        add :id, :uuid, null: false, primary_key: true
        add :name, :string
        add :description, :string
      end

      create table(:user_access_groups, primary_key: false) do
        add :user_id, references(:users, type: :uuid), primary_key: true
        add :access_group_id, references(:access_groups, type: :uuid), primary_key: true

        timestamps()
      end

      create index(:user_access_groups, [:user_id])
      create index(:user_access_groups, [:access_group_id])

      create table(:dataset_access_groups, primary_key: false) do
        add :dataset_id, references(:datasets, type: :string), primary_key: true
        add :access_group_id, references(:access_groups, type: :uuid), primary_key: true

        timestamps()
      end

      create index(:dataset_access_groups, [:dataset_id])
      create index(:dataset_access_groups, [:access_group_id])
    end
end

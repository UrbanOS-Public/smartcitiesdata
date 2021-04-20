defmodule Andi.Repo.Migrations.UserOrgJoin do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      remove :org_owner_id
    end

    create table(:user_organizations, primary_key: false) do
      add :user_id, references(:users, type: :uuid), primary_key: true
      add :organization_id, references(:organizations, type: :uuid), primary_key: true

      timestamps()
    end

    create index(:user_organizations, [:user_id])
    create index(:user_organizations, [:organization_id])
  end
end

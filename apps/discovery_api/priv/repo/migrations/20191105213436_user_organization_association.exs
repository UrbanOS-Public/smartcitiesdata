defmodule DiscoveryApi.Repo.Migrations.OrgUserAssociation do
  use Ecto.Migration

  def change do
    create table(:user_organizations, primary_key: false) do
      add :user_id, references(:users, type: :uuid), primary_key: true
      add :organization_id, references(:organizations, type: :string), primary_key: true

      timestamps()
    end

    create index(:user_organizations, [:user_id])
    create index(:user_organizations, [:organization_id])
  end
end

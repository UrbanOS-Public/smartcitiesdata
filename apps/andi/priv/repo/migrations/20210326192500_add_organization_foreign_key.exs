defmodule Andi.Repo.Migrations.AddOrganizationForeignKey do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :org_owner_id, references(:users, type: :uuid), null: true
    end
  end
end

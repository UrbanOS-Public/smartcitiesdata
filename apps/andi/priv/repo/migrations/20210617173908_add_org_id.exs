defmodule Andi.Repo.Migrations.AddOrgAssociation do
  use Ecto.Migration

  def change do
    alter table(:datasets) do
      add :organization_id, references(:organizations, type: :uuid)
    end
  end
end

defmodule Andi.Repo.Migrations.AddOrgAssociation do
  use Ecto.Migration
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.Repo

  def change do
    alter table(:datasets) do
      add :organization_id, references(:organizations, type: :uuid)
    end
  end
end
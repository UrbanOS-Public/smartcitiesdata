defmodule Andi.Repo.Migrations.CreateOrgs do
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :description, :text
      add :orgName, :string
      add :orgTitle, :string
      add :homepage, :string
      add :logoUrl, :string
      add :dataJSONUrl, :string
    end
  end
end

defmodule DiscoveryApi.Repo.Migrations.CreateOrganizationTable do
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add(:id, :string, null: false, primary_key: true)
      add(:name, :string, null: false, size: 500)
      add(:title, :string, null: false, size: 500)
      add(:description, :text)
      add(:homepage, :string, size: 500)
      add(:logo_url, :string, size: 500)
      add(:ldap_dn, :string, size: 500)

      timestamps()
    end
  end
end

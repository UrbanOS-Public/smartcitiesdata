defmodule DiscoveryApi.Repo.Migrations.DropOrgLdapDnColumn do
  use Ecto.Migration

  def change do
    alter table("organizations") do
      remove :ldap_dn, :string, size: 500
    end
  end
end

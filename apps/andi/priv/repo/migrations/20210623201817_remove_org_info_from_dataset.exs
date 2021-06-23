defmodule Andi.Repo.Migrations.RemoveOrgInfoFromDataset do
  use Ecto.Migration

  def change do
    alter table(:technical) do  
      remove :orgId
      remove :orgName
    end
    alter table(:business) do  
      remove :orgTitle
    end
  end
end

defmodule Andi.Repo.Migrations.OrgStringIds do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      modify :id, :string
    end
  end
end

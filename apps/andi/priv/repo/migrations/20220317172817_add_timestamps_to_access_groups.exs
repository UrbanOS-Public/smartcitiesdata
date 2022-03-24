defmodule Andi.Repo.Migrations.AddTimestampsToAccessGroups do
  use Ecto.Migration

  def change do
    alter table(:access_groups) do
      timestamps()
    end
  end
end

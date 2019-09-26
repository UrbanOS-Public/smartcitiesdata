defmodule DiscoveryApi.Repo.Migrations.CreateUserTable do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :subject_id, :string, null: false
      add :username, :string, null: false

      timestamps()
    end

    create unique_index(:users, [:subject_id])
  end
end

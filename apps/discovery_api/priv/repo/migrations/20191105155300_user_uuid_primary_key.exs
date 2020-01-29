defmodule DiscoveryApi.Repo.Migrations.UserUuidPrimaryKey do
  use Ecto.Migration

  import Ecto.Query, only: [from: 2]

  alias DiscoveryApi.Repo
  alias DiscoveryApi.Schemas.Visualizations.Visualization

  def up do
    # Alter 'users' to have a primary key that is a UUID rather than an auto-incrementing id
    # Update 'owner_id' in 'visualizations' to use the new 'user' id
    execute ~s|CREATE EXTENSION IF NOT EXISTS "uuid-ossp";|

    alter table(:users) do
      add :new_id, :uuid, default: fragment("uuid_generate_v4()")
    end

    alter table(:visualizations) do
      add :new_owner_id, :uuid
    end

    load_new_owner_ids()

    alter table(:visualizations) do
      modify :new_owner_id, :uuid, null: false
    end

    alter table(:visualizations) do
      remove :owner_id
    end

    alter table(:users) do
      remove :id
      modify :new_id, :uuid, primary_key: true
    end

    rename table(:users), :new_id, to: :id
    rename table(:visualizations), :new_owner_id, to: :owner_id

    alter table(:visualizations) do
      modify :owner_id, references(:users, type: :uuid)
    end
  end

  def down do
    alter table(:users) do
      add :new_id, :serial
    end

    alter table(:visualizations) do
      add :new_owner_id, :integer
    end

    load_new_owner_ids()

    alter table(:visualizations) do
      modify :new_owner_id, :integer, null: false
    end

    alter table(:visualizations) do
      remove :owner_id
    end

    alter table(:users) do
      remove :id
      modify :new_id, :integer, primary_key: true
    end

    rename table(:users), :new_id, to: :id
    rename table(:visualizations), :new_owner_id, to: :owner_id

    alter table(:visualizations) do
      modify :owner_id, references(:users)
    end
  end

  defp load_new_owner_ids() do
    flush()
    from(
      visualization in Visualization,
      update: [set: [new_owner_id: fragment("select users.new_id from users where users.id = ?", visualization.owner_id)]])
    |> Repo.update_all([])
  end
end

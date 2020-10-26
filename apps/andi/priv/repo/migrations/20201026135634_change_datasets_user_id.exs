defmodule Andi.Repo.Migrations.ChangeDatasetsUserId do
  use Ecto.Migration

  def change do
    rename table(:datasets), :owner_id, to: :user_id
  end
end

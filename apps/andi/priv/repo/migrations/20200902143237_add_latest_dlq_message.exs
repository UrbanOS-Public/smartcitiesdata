defmodule Andi.Repo.Migrations.AddLatestDlqMessage do
  use Ecto.Migration

  def change do
    alter table(:datasets) do
      add :dlq_message, :map
    end
  end
end

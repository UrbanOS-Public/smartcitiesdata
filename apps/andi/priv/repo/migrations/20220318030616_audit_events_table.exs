defmodule Andi.Repo.Migrations.AuditEventsTable do
  use Ecto.Migration

  def change do
    create table(:audit_events, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :user_id, :string
      add :event_type, :string
      add :event, :map

      timestamps()
    end
  end
end

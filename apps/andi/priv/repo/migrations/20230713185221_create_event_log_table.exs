defmodule Andi.Repo.Migrations.CreateEventLogTable do
  use Ecto.Migration

  def change do
    create table(:event_log, primary_key: false) do
      add(:title, :string)
      add(:timestamp, :utc_datetime)
      add(:source, :string)
      add(:description, :string)
      add(:dataset_id, :uuid, primary_key: true)
    end
  end
end

defmodule Andi.Repo.Migrations.AddMessageErrorTable do
  use Ecto.Migration

  def change do
    create table(:message_error, primary_key: false) do
      add(:dataset_id, :uuid, primary_key: true)
      add(:ingestion_id, :uuid)
      add(:has_current_error, :boolean)
      add(:last_error_time, :utc_datetime)
    end
  end
end





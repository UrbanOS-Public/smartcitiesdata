defmodule Andi.Repo.Migrations.CreateCommonExtractStep do
  use Ecto.Migration

  def change do
    create table(:extract_step, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :string)
      add(:context, :map)
      add :technical_id, references(:technical, type: :uuid, on_delete: :delete_all)
      add :sequence, :serial
    end
    execute "select setval(pg_get_serial_sequence('extract_step', 'sequence'), 1)"
  end
end

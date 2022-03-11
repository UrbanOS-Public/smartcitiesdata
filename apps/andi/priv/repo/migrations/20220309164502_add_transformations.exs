defmodule Andi.Repo.Migrations.AddTransformations do
  use Ecto.Migration

  def change do
    create table(:transformation, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :string)
      add(:parameters, :map)
      add :ingestion_id, references(:ingestions, type: :uuid, on_delete: :delete_all)
      add :sequence, :serial
    end

    alter table(:ingestions) do
      add :transformations, {:array, :map}, default: []
    end

    execute "select setval(pg_get_serial_sequence('transformation', 'sequence'), 1)"
  end
end

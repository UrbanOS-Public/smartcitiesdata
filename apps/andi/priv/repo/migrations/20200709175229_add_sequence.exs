defmodule Andi.Repo.Migrations.AddSequence do
  use Ecto.Migration

  def change do
    alter table(:data_dictionary) do
      add :sequence, :serial
    end
    execute "select setval(pg_get_serial_sequence('data_dictionary', 'sequence'), 1)"
  end
end

defmodule Andi.Repo.Migrations.AddFormat do
  use Ecto.Migration

  def change do
    alter table(:data_dictionary, primary_key: false) do
      add :format, :string
    end
  end
end

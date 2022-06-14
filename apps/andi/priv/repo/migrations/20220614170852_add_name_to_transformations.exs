defmodule Andi.Repo.Migrations.AddNameToTransformations do
  use Ecto.Migration

  def change do
    alter table(:transformation) do
      add :name, :string
    end
  end

end

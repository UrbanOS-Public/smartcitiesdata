defmodule Andi.Repo.Migrations.ChangeExtractColumnToAction do
  use Ecto.Migration

  def change do
    rename table("extract_http_step"), :method, to: :action

    alter table(:extract_http_step) do
      add :protocol, {:array, :string}
    end
  end
end

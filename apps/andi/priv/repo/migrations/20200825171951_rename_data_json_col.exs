defmodule Andi.Repo.Migrations.RenameDataJsonCol do
  use Ecto.Migration

  def change do
    rename table("organizations"), :dataJSONUrl, to: :dataJsonUrl
  end
end

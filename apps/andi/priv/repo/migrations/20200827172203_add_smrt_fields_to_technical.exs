defmodule Andi.Repo.Migrations.AddSmrtFieldsToTechnical do
  use Ecto.Migration

  def change do
    alter table(:technical) do
      add :allow_duplicates, :boolean
      add :authUrl, :string
      add :authBodyEncodeMethod, :string
      add :authBody, :map
      add :authHeaders, :map
      add :credentials, :boolean
      add :protocol, {:array, :string}
    end
  end
end

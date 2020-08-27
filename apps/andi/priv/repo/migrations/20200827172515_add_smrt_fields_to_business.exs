defmodule Andi.Repo.Migrations.AddSmrtFieldsToBusiness do
  use Ecto.Migration

  def change do
    alter table(:business) do
      add :authorEmail, :string
      add :authorName, :string
      add :categories, {:array, :string}
      add :conformsToUri, :string
      add :describedByMimeType, :string
      add :describedByUrl, :string
      add :parentDataset, :string
      add :referenceUrls, {:array, :string}
    end
  end
end

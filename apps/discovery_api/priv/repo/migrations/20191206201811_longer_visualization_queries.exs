defmodule DiscoveryApi.Repo.Migrations.LongerVisualizationQueries do
  use Ecto.Migration

  def change do
    alter table(:visualizations) do
      modify(:query, :text, from: :string)
    end
  end
end

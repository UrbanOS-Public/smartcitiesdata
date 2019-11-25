defmodule DiscoveryApi.Repo.Migrations.AddChartField do
  use Ecto.Migration

  def change do
    alter table(:visualizations) do
      add(:chart, :text, null: true)
    end
  end
end

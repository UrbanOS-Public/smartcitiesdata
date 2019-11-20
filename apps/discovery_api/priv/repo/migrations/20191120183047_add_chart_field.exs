defmodule DiscoveryApi.Repo.Migrations.AddChartField do
  use Ecto.Migration

  def change do
    alter table(:visualizations) do
      add(:chart, :string, null: true, size: 20_000)
    end
  end
end

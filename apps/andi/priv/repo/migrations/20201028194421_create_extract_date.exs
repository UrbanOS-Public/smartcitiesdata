defmodule Andi.Repo.Migrations.CreateExtractDate do
  use Ecto.Migration

  def change do
    create table(:extract_date_step, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :string)
      add(:assigns, :map)
      add(:destination, :string)
      add(:deltaTimeUnit, :string)
      add(:deltaTimeValue, :integer)
      add(:format, :string)
      add :technical_id, references(:technical, type: :uuid, on_delete: :delete_all)
    end
  end
end

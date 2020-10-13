defmodule Andi.Repo.Migrations.CreateExtractSteps do
  use Ecto.Migration

  def change do
    create table(:extract_http_step, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)
      add(:type, :string, null: false)
      add(:method, :string, null: false)
      add(:url, :string, null: false)
      add(:body, :string, null: true)
      add(:assigns, :map)
      add :technical_id, references(:technical, type: :uuid, on_delete: :delete_all), null: false
    end

    create table(:extract_http_headers, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :key, :string
      add :value, :string
      add :extract_http_step_id, references(:extract_http_step, type: :uuid, on_delete: :delete_all), null: false
    end

    create table(:extract_http_queryParams, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :key, :string
      add :value, :string
      add :extract_http_step_id, references(:extract_http_step, type: :uuid, on_delete: :delete_all), null: false
    end
  end
end

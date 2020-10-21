defmodule Andi.Repo.Migrations.CreateExtractSteps do
  use Ecto.Migration

  def change do
    create table(:extract_http_step, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :string)
      add(:method, :string)
      add(:url, :string)
      add(:body, :string)
      add(:assigns, :map)
      add :technical_id, references(:technical, type: :uuid, on_delete: :delete_all)
    end

    create table(:extract_http_headers, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :key, :string
      add :value, :string
      add :extract_http_step_id, references(:extract_http_step, type: :uuid, on_delete: :delete_all)
    end

    create table(:extract_http_queryParams, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :key, :string
      add :value, :string
      add :extract_http_step_id, references(:extract_http_step, type: :uuid, on_delete: :delete_all)
    end
  end
end

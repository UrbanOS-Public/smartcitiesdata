defmodule Andi.Repo.Migrations.CreateDatasets do
  use Ecto.Migration

  def change do
    create table(:datasets, primary_key: false) do
      add(:id, :string, null: false, primary_key: true)
      add :ingestedTime, :utc_datetime
    end

    create table(:technical, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :dataName, :string
      add :orgName, :string
      add :private, :boolean
      add :schema, {:array, :map}, default: []
      add :systemName, :string
      add :sourceFormat, :string
      add :sourceType, :string
      add :sourceUrl, :string
      add :topLevelSelector, :string
      add :orgId, :string
      add :cadence, :string
      add :dataset_id, references(:datasets, type: :string, on_delete: :delete_all), null: false
    end

    create table(:business, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :benefitRating, :float
      add :contactEmail, :string
      add :contactName, :string
      add :dataTitle, :string
      add :description, :text
      add :homepage, :string
      add :issuedDate, :date
      add :keywords, {:array, :string}, default: []
      add :language, :string
      add :license, :string
      add :modifiedDate, :date
      add :orgTitle, :string
      add :publishFrequency, :string
      add :riskRating, :float
      add :spatial, :string
      add :temporal, :string
      add :rights, :string
      add :dataset_id, references(:datasets, type: :string, on_delete: :delete_all), null: false
    end

    create table(:data_dictionary, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :name, :string
      add :type, :string
      add :itemType, :string
      add :selector, :string
      add :biased, :string
      add :demographic, :string
      add :description, :text
      add :masked, :string
      add :pii, :string
      add :rationale, :string
      add :bread_crumb, :string
      add :technical_id, references(:technical, type: :uuid, on_delete: :delete_all)
      add :parent_id, references(:data_dictionary, type: :uuid, on_delete: :delete_all)
      add :dataset_id, references(:datasets, type: :string, on_delete: :delete_all)
    end

    create table(:source_headers, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :key, :string
      add :value, :string
      add :technical_id, references(:technical, type: :uuid, on_delete: :delete_all), null: false
    end

    create table(:source_query_params, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :key, :string
      add :value, :string
      add :technical_id, references(:technical, type: :uuid, on_delete: :delete_all), null: false
    end
  end
end

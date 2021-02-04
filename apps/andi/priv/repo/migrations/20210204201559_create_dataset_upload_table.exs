defmodule Andi.Repo.Migrations.CreateDatasetUploadTable do
  use Ecto.Migration

  def change do
    create table(:dataset_upload, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:dataset_id, :uuid)
      add(:timestamp, :utc_datetime)
      add(:user_uploading, :string)
      add(:upload_success, :boolean)
    end
  end
end

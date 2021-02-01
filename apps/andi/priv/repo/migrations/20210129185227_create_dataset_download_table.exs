defmodule Andi.Repo.Migrations.CreateDatasetDownloadTable do
  use Ecto.Migration

  def change do
    create table(:dataset_download, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:client_ip_addr, :string)
      add(:dataset_id, :uuid)
      add(:dataset_link, :string)
      add(:download_success, :boolean)
      add(:timestamp, :utc_datetime)
      add(:user_accessing, :string)
    end
  end
end

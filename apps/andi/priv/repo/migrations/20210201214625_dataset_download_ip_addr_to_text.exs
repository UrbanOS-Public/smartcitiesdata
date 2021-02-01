defmodule Andi.Repo.Migrations.DatasetDownloadIpAddrToText do
  use Ecto.Migration

  def change do
    alter table(:dataset_download) do
      add :request_headers, :text
      remove :client_ip_addr
    end
  end
end

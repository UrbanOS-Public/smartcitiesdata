defmodule Andi.Repo.Migrations.ExtractUrlToText do
  use Ecto.Migration

  def change do
    alter table(:extract_http_step) do
      modify :url, :text
      modify :body, :text
    end
  end
end

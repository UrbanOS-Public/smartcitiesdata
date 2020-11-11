defmodule Andi.Repo.Migrations.AddSubmissionStatusToDataset do
  use Ecto.Migration

  def change do
    alter table(:datasets) do
      add :submission_status, :string
    end
  end
end

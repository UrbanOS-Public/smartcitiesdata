defmodule Andi.Repo.Migrations.AddSubmissionStatusToIngestion do
  use Ecto.Migration

  def change do
    alter table(:ingestions) do
      add :submission_status, :string, default: "draft", null: false
    end
  end

end

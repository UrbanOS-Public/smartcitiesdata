defmodule Andi.Repo.Migrations.RenameSubmissionStatus do
  use Ecto.Migration

  def change do
    rename table(:ingestions), :submission_status, to: :submissionStatus
  end
end

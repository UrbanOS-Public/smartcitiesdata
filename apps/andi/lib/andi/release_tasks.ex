defmodule Andi.ReleaseTasks do
  @moduledoc """
  Tasks to be run when Andi is deployed.  Its main function is to apply Ecto database migrations.
  """

  def migrate do
    {:ok, _} = Application.ensure_all_started(:andi)

    path = Application.app_dir(:andi, "priv/repo/migrations")

    Ecto.Migrator.run(Andi.Repo, path, :up, all: true)
  end
end

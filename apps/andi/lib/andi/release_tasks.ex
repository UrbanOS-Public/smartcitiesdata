defmodule Andi.ReleaseTasks do
  @moduledoc """
  Tasks to be run when Andi is deployed.  Its main function is to apply Ecto database migrations.
  """
  require Logger

  def migrate do
    # Load the application configuration without starting it
    Application.load(:andi)

    # Start only the applications needed for database migrations
    Application.ensure_all_started(:ssl)
    Application.ensure_all_started(:postgrex)
    Application.ensure_all_started(:ecto_sql)

    # Start the Repo as a standalone process
    {:ok, _} = Andi.Repo.start_link(pool_size: 2)

    # Run migrations
    path = Application.app_dir(:andi, "priv/repo/migrations")

    Logger.info("Running migrations from #{path}")
    Ecto.Migrator.run(Andi.Repo, path, :up, all: true)
    Logger.info("Migrations completed successfully")

    # Stop the Repo
    :ok = Andi.Repo.stop()
  end
end

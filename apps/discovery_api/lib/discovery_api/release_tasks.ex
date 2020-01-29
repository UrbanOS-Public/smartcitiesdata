defmodule DiscoveryApi.ReleaseTasks do
  @moduledoc """
  Tasks to be run when Discovery API is deployed.  Its main function is to apply Ecto database migrations.
  """

  def migrate do
    {:ok, _} = Application.ensure_all_started(:discovery_api)

    path = Application.app_dir(:discovery_api, "priv/repo/migrations")

    Ecto.Migrator.run(DiscoveryApi.Repo, path, :up, all: true)
  end
end

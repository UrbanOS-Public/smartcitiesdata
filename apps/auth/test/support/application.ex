defmodule Auth.Application do
  @moduledoc """
  Ecto demands a real database for testing, so here it is
  """

  use Application

  require Logger

  def start(_type, _args) do
    children =
      [
        ecto_repo(),
        guardian_db_sweeper()
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Auth.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp ecto_repo do
    case Application.get_env(:auth, Auth.Repo) do
      nil -> []
      _ -> [{Auth.Repo, []}]
    end
  end

  defp guardian_db_sweeper do
    case Application.get_env(:auth, Guardian.DB) do
      nil -> []
      config ->
        Application.put_env(:guardian, Guardian.DB, config)
        Supervisor.Spec.worker(Guardian.DB.Token.SweeperServer, [])
    end
  end
end

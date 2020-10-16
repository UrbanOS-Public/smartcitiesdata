defmodule Auth.Application do
  @moduledoc """
  Ecto demands a real database for testing, so here it is
  """

  use Application

  require Logger

  def start(_type, _args) do
    children =
      [
        ecto_repo()
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Auth.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp ecto_repo do
    Application.get_env(:auth, Auth.Repo)
    |> case do
      nil -> []
      _ -> [{Auth.Repo, []}]
    end
  end
end

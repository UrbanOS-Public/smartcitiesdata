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
    case {Application.get_env(:auth, Auth.Repo), disabled?()} do
      {nil, _} -> []
      {_, true} -> []
      {_, false} -> [{Auth.Repo, []}]
    end
  end

  def disabled?() do
    Application.get_env(:auth, :disable_app) || false
  end

  def disable() do
    Application.put_env(:auth, :disable_app, true)
  end
end

defmodule Auth.Application do
  @moduledoc """
  Ecto demands a real database for testing, so here it is
  """

  use Application

  require Logger

  def start(_type, _args) do
    IO.puts("starting app")
    children =
      [
        {Auth.Repo, []}
      ]
      |> List.flatten()


    opts = [strategy: :one_for_one, name: Auth.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

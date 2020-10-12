use Mix.Config

config :auth,
  divo: [{Auth.DivoPostgres, []}],
  ecto_repos: [Auth.Repo],
  divo_wait: [dwell: 2000, max_tries: 35]

config :auth, Auth.Repo,
  database: "auth_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  port: "5456"

config :guardian, Guardian.DB, repo: Auth.Repo

defmodule Auth.DivoPostgres do
  @moduledoc """
  Defines a postgres stack compatible with divo
  for building a docker-compose file.
  """

  def gen_stack(_envar) do
    %{
      postgres: %{
        image: "postgres:9.6.16",
        ports: ["5456:5432"],
        healthcheck: %{
          test: ["CMD-SHELL", "pg_isready --username=postgres --dbname=postgres"],
          interval: "10s",
          timeout: "5s",
          retries: 5
        }
      }
    }
  end
end

Application.ensure_all_started(:ecto)
Application.ensure_all_started(:ecto_sql)
Application.ensure_all_started(:postgrex)
Auth.Application.start([], [])

Logger.configure(level: :info)
Divo.Suite.start()
# good old umbrella and high level configs
Application.put_env(:guardian, Guardian.DB, repo: Auth.Repo)
ExUnit.start()

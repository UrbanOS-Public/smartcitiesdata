Auth.Application.disable()
Divo.Suite.start()
# good old umbrella and high level configs
Application.put_env(:guardian, Guardian.DB, repo: Andi.Repo)
ExUnit.start()

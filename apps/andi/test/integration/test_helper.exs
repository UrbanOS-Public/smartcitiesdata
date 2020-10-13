# Divo.Suite.start()
Application.ensure_all_started(:andi)
# good old umbrella and high level configs
Application.put_env(:guardian, Guardian.DB, [repo: Andi.Repo])
ExUnit.start()

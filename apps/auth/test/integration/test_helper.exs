Application.ensure_all_started(:ecto)
Application.ensure_all_started(:ecto_sql)
Application.ensure_all_started(:postgrex)
Auth.Application.start([], [])

Logger.configure(level: :info)
Divo.Suite.start()
ExUnit.start()

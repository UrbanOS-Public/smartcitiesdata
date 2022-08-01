import Config

db_name = "auth_test"
db_username = "postgres"
db_password = "postgres"
db_port = "5456"

config :auth,
  divo: [
    {
      DivoPostgres,
      [
        user: db_username,
        database: db_name,
        port: db_port
      ]
    }
  ],
  ecto_repos: [Auth.Repo],
  divo_wait: [dwell: 2000, max_tries: 35]

config :auth, Auth.Repo,
  database: db_name,
  username: db_username,
  password: db_password,
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  port: db_port

config :auth, Guardian.DB, repo: Auth.Repo

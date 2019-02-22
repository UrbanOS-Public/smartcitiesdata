defmodule Mix.Tasks.Docker.Start do
  @moduledoc false
  use Mix.Task
  alias Mix.Project
  @impl Mix.Task
  def run(_args) do
    app = Project.config()[:app]
    file = "#{System.get_env("TMPDIR")}/#{app}.compose"
    IO.puts("FILE : #{file}")

    app
    |> Application.get_env(:docker)
    |> Jason.encode!()
    |> write(file)

    Mix.shell().cmd("docker-compose -p #{app} -f #{file} up -d --build")

    wait_for = Application.get_env(app, :docker_wait_for)

    if wait_for do
      IO.puts("Checking for #{wait_for}")
      Mix.shell().cmd("docker-compose -p #{app} -f #{file} logs -f | grep -q '#{wait_for}'")
    end
  end

  defp write(content, path) do
    File.write!(path, content)
  end
end

defmodule Mix.Tasks.Docker.Stop do
  @moduledoc false
  use Mix.Task
  alias Mix.Project

  @impl Mix.Task
  def run(_args) do
    app = Project.config()[:app]
    file = "#{System.get_env("TMPDIR")}/#{app}.compose"

    Mix.shell().cmd("docker-compose -p #{app} -f #{file} down")
  end
end

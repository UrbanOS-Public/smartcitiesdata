defmodule Mix.Tasks.Docker.Start do
  @moduledoc false
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    app = Mix.Project.config()[:app]
    file = "#{System.get_env("TMPDIR")}#{app}.compose"

    IO.puts("FILE : #{file}")

    app
    |> Application.get_env(:docker)
    |> Jason.encode!()
    |> write(file)

    Mix.shell().cmd("docker-compose -p #{app} -f #{file} up -d")

    wait_for = Application.get_env(app, :docker_wait_for)

    if wait_for do
      IO.puts("Sleeping")
      Process.sleep(5000)
      IO.puts("Checking for #{wait_for}")
      Mix.shell().cmd("docker-compose -p #{app} -f #{file} logs --tail 10000 | grep -q '#{wait_for}'")
      IO.puts("Done checking for #{wait_for}")
    end
  end

  defp write(content, path) do
    File.write!(path, content)
  end
end

defmodule Mix.Tasks.Docker.Stop do
  @moduledoc false
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    app = Mix.Project.config()[:app]
    file = "#{System.get_env("TMPDIR")}#{app}.compose"

    Mix.shell().cmd("docker-compose -p #{app} -f #{file} down")
  end
end

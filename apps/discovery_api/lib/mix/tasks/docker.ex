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
      condition = fn ->
        IO.puts("Waiting for log '#{wait_for}'")
        status_code = Mix.shell().cmd("docker-compose -p #{app} -f #{file} logs --tail 100000 | grep -q '#{wait_for}'")

        case status_code do
          0 ->
            IO.puts("Found log '#{wait_for}'")
            true

          _ ->
            false
        end
      end

      Patiently.wait_for!(
        condition,
        dwell: 500,
        max_tries: 20
      )
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

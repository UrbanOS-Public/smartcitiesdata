defmodule Mix.Tasks.Scos.Application.Stop do
  @moduledoc false
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Application.stop(Mix.Project.config[:app])
  end
end

defmodule Mix.Tasks.App.Version do
  @moduledoc false
  def run(_) do
    Mix.Project.config()
    |> Keyword.get(:version)
    |> IO.puts()
  end
end

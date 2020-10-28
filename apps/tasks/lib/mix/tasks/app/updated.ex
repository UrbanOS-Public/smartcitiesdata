defmodule Mix.Tasks.App.Updated do
  @moduledoc """
  A task that can be run in an app to see if it has been updated
  """

  def run([]), do: run(["origin/master"])
  def run([sha_to_diff_against]) do
    git_repository = git_repository()
    paths_to_check = umbrella_dependency_paths() ++ [application_path()]

    updated? = Enum.any?(paths_to_check, &updated?(&1, git_repository, sha_to_diff_against))

    if updated? do
      System.halt(0)
    else
      System.halt(1)
    end
  end

  defp updated?(path, repo, sha) do
    case Git.diff(repo, ["--name-only", sha, "--", path]) do
      {:ok, ""} -> false
      _ -> true
    end
  end

  defp git_repository() do
    path = String.replace(File.cwd!(), application_path(), "")
    %Git.Repository{path: path}
  end

  defp application_path() do
    name = Mix.Project.config()
    |> Keyword.get(:app)

    "apps/#{name}"
  end

  defp umbrella_dependency_paths() do
    Mix.Project.config()
    |> Keyword.get(:deps)
    |> Enum.filter(fn
      {_n, v} when is_list(v) -> Keyword.get(v, :in_umbrella, false)
      _ -> false
    end)
    |> Enum.filter(fn
      {_n, v} ->
        case Keyword.get(v, :only, []) do
          [] -> true
          _ -> false
        end
    end)
    |> Enum.map(fn {n, _v} -> "apps/#{n}" end)
  end
end

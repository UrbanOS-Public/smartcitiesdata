defmodule VersionDiffer do
  require Logger

  def cli do
    changed_apps = get_changed_apps()
    changed_app_versions = get_app_versions(changed_apps)
    tags = get_tags()

    app_version_messages =
      changed_app_versions
      |> Enum.filter(&(&1 in tags))
      |> Enum.map(&format_app/1)

    case app_version_messages do
      [] ->
        IO.puts("Did not detect any app version problems")

      apps ->
        IO.puts("Tags already exist for #{Enum.join(apps, ", ")}. Please update each `apps/${app}/mix.exs` with a new version.")
    end
  end

  defp format_app({app, vsn}) do
    "`#{String.capitalize(app)} #{
      Enum.join([vsn.major, vsn.minor, vsn.patch], ".")
    }`"
  end

  def get_changed_apps(commit_range \\ "origin/master") do
    with {raw, 0} <- get_raw_file_diff(commit_range) do
      extract_apps(raw)
    else
      error ->
        Logger.error("Error getting file diff: (#{inspect(error)})")
        []
    end
  end

  def get_app_versions(apps) do
    Application.ensure_all_started(:mix)

    Enum.map(apps, &get_app_version/1)
  end

  def get_tags do
    with {tags, 0} <- System.cmd("git", ["tag"]) do
      tags
      |> String.split("\n")
      |> Enum.map(&String.split(&1, "@"))
      |> Enum.reject(&(length(&1) != 2))
      |> Enum.map(fn [app, vsn] -> {app, Version.parse!(vsn)} end)
    else
      {result, code} -> raise inspect({result, code})
    end
  end

  defp get_app_version(app) do
    with app_path = "apps/#{app}/mix.exs",
         true <- File.exists?(app_path),
         {{:module, module, _, _}, _} <- Code.eval_file(app_path) do
      {app, module.project()[:version] |> Version.parse!()}
    end
  end

  defp get_raw_file_diff(commit_range) do
    System.cmd("git", ["diff", "--name-status", commit_range])
  end

  defp extract_apps(raw) do
    raw
    |> String.split(["\n", "\t"])
    |> Enum.map(&String.split(&1, "/"))
    |> Enum.map(fn
      ["apps", app | _rest] -> app
      _other -> []
    end)
    |> List.flatten()
    |> MapSet.new()
    |> MapSet.to_list()
  end
end

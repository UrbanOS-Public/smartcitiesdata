defmodule Mix.Tasks.App.TagExists do
  @moduledoc """
  Determines if a changed application has a version that matches an existing tag
  """

  def run(_) do
    app_name = application_name()
    app_version = application_version()
    app_tags = application_tags(app_name)

    case app_version in app_tags do
      false ->
        IO.puts("Did not detect any app version problems")
        System.halt(1)

      true ->
        IO.puts("Tag exists for #{format_app(app_name, app_version)}. Please update `apps/#{app_name}/mix.exs` with a new version.")
        System.halt(0)
    end
  end

  defp application_version() do
    Mix.Project.config()
    |> Keyword.get(:version)
  end


  defp application_name() do
    Mix.Project.config()
    |> Keyword.get(:app)
    |> to_string()
  end

  defp format_app(app, vsn) do
    "`#{String.capitalize(app)} #{vsn}`"
  end

  def application_tags(application) do
    case System.cmd("git", ["tag"]) do
      {tags, 0} ->
        tags
        |> String.split("\n")
        |> Enum.map(&String.split(&1, "@"))
        |> Enum.reject(&(length(&1) != 2))
        |> Enum.reject(fn [app, _vsn] -> app != application end)
        |> Enum.map(fn [_app, vsn] -> vsn end)
      {result, code} ->
        raise inspect({result, code})
    end
  end
end

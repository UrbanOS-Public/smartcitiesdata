defmodule Reaper.DataSlurper.Http do
  @moduledoc """
  Downloads http/https files as stream to local filesystem
  """
  @behaviour Reaper.DataSlurper
  alias Reaper.DataSlurper
  require Logger
  @download_timeout Application.get_env(:reaper, :download_timeout, 600_000)

  @impl DataSlurper
  def handle?(url) do
    String.starts_with?(url, "http")
  end

  @impl DataSlurper
  def slurp(url, dataset_id) do
    filename = DataSlurper.determine_filename(dataset_id)
    file = File.open!(filename, [:write])

    url
    |> follow_redirect()
    |> Downstream.get!(file, timeout: @download_timeout)

    File.close(file)
    {:file, filename}
  rescue
    error ->
      Logger.error(fn -> "Unable to retrieve data for #{dataset_id}: #{Downstream.Error.message(error)}" end)
      reraise error, __STACKTRACE__
  end

  defp follow_redirect(url) do
    case HTTPoison.head(url) do
      {:ok, %HTTPoison.Response{status_code: status_code} = response} when status_code in [301, 302] ->
        response
        |> location()
        |> follow_redirect()

      _ ->
        url
    end
  end

  defp location(%HTTPoison.Response{headers: headers}) do
    {_location, url} =
      headers
      |> Enum.find(fn {key, _value} -> String.downcase(key) == "location" end)

    url
  end
end

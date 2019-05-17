defmodule Reaper.Extractor do
  @moduledoc false
  use Tesla
  require Logger

  @download_timeout Application.get_env(:reaper, :download_timeout, 600_000)

  plug(Tesla.Middleware.FollowRedirects)
  plug(Tesla.Middleware.Retry, delay: 500, max_retries: 10)

  def extract("sftp" <> _rest = url, dataset_id, format) do
    case Reaper.SftpExtractor.extract(url, dataset_id) do
      {:ok, data} ->
        if format == "csv" do
          filename = determine_filename(dataset_id)
          File.write!(filename, data)
          {:file, filename}
        else
          data
        end

      {:error, reason} ->
        raise "Failed calling '" <> url <> "': " <> inspect(reason)
    end
  end

  def extract(url, dataset_id, "csv") do
    filename = determine_filename(dataset_id)
    file = File.open!(filename, [:write])

    url
    |> follow_redirect()
    |> Downstream.get!(file, timeout: @download_timeout)

    File.close(file)
    {:file, filename}
  rescue
    error ->
      Logger.error(fn -> "Unable to retrieve data for #{dataset_id}: #{error.message}" end)
      reraise error, __STACKTRACE__
  end

  def extract(url, _dataset_id, _format) do
    case get(url) do
      {:ok, response} ->
        response.body

      {:error, reason} ->
        target =
          url
          |> String.split("?")
          |> List.first()

        raise "Failed calling '" <> target <> "': " <> inspect(reason)
    end
  end

  defp determine_filename(dataset_id) do
    Application.get_env(:reaper, :download_dir, "") <> dataset_id
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

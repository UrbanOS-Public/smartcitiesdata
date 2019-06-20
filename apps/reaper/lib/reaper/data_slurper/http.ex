defmodule Reaper.DataSlurper.Http do
  @moduledoc """
  Downloads http/https files as stream to local filesystem
  """
  @behaviour Reaper.DataSlurper
  alias Reaper.DataSlurper
  alias Reaper.Http.Downloader
  require Logger

  defmodule HttpDownloadTimeoutError do
    defexception [:message]
  end

  @impl DataSlurper
  def handle?(url) do
    String.starts_with?(url, "http")
  end

  @impl DataSlurper
  def slurp(url, dataset_id, headers \\ %{}, protocol \\ nil) do
    filename = DataSlurper.determine_filename(dataset_id)
    download(dataset_id, url, filename, headers, protocol)
    {:file, filename}
  rescue
    error ->
      Logger.error(fn -> "Unable to retrieve data for #{dataset_id}: #{Exception.message(error)}" end)
      reraise error, __STACKTRACE__
  end

  defp download(dataset_id, url, filename, headers, protocol) do
    Task.async(fn -> Downloader.download(url, headers, to: filename, protocol: protocol) end)
    |> Task.await(download_timeout())
  catch
    :exit, _ ->
      message = "Timed out downloading dataset #{dataset_id} at #{url} in #{download_timeout()} ms"
      raise HttpDownloadTimeoutError, message
  end

  defp download_timeout do
    Application.get_env(:reaper, :http_download_timeout, 600_000)
  end
end

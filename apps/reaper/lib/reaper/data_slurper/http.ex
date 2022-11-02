defmodule Reaper.DataSlurper.Http do
  @moduledoc """
  Downloads http/https files as stream to local filesystem
  """
  use Properties, otp_app: :reaper

  @behaviour Reaper.DataSlurper
  alias Reaper.DataSlurper
  alias Reaper.Http.Downloader
  require Logger

  getter(:http_download_timeout, generic: true, default: 7_200_000)

  defmodule HttpDownloadTimeoutError do
    defexception [:message]
  end

  @impl DataSlurper
  def handle?(url) do
    String.starts_with?(url, "http")
  end

  @impl DataSlurper
  def slurp(url, ingestion_id, headers \\ %{}, protocol \\ nil, action \\ "GET", body \\ "") do
    filename = DataSlurper.determine_filename(ingestion_id)
    download(ingestion_id, url, filename, headers, protocol, action, body)
    {:file, filename}
  rescue
    error ->
      Logger.error(fn ->
        "Unable to retrieve data for #{ingestion_id}: #{Exception.message(error)}"
      end)
      reraise inspect(error), __STACKTRACE__
  end

  defp download(ingestion_id, url, filename, headers, protocol, action, body) do
    Task.async(fn -> Downloader.download(url, headers, to: filename, protocol: protocol, action: action, body: body) end)
    |> Task.await(http_download_timeout())
  catch
    :exit, {:timeout, _} ->
      message = "Timed out downloading ingestion #{ingestion_id} at #{url} in #{http_download_timeout()} ms"

      raise HttpDownloadTimeoutError, message

    :exit, error ->
      reraise inspect(error), __STACKTRACE__
  end
end

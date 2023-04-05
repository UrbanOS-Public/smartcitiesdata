defmodule Reaper.DataSlurper do
  @moduledoc """
  Downloads data to the file system from various sources
  """
  use Properties, otp_app: :reaper

  @type url :: String.t()
  @type ingestion_id :: String.t()
  @type filename :: String.t()
  @type headers :: list()
  @type protocol :: list()

  @callback handle?(url()) :: boolean()
  @callback slurp(url(), ingestion_id(), headers(), protocol()) :: {:file, filename()} | no_return()

  @implementations [
    Reaper.DataSlurper.Http,
    Reaper.DataSlurper.Sftp,
    Reaper.DataSlurper.S3,
    Reaper.DataSlurper.Ftp
  ]

  getter(:download_dir, generic: true, default: "")

  def slurp(url, ingestion_id, headers \\ %{}, protocol \\ nil, action \\ "GET", body \\ "") do
    @implementations
    |> Enum.find(&handle?(&1, url))
    |> apply(:slurp, [url, ingestion_id, headers, protocol, action, body])
  end

  def determine_filename(ingestion_id) do
    download_dir() <> ingestion_id
  end

  defp handle?(implementation, url) do
    apply(implementation, :handle?, [url])
  end
end

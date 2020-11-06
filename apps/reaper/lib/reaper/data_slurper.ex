defmodule Reaper.DataSlurper do
  @moduledoc """
  Downloads data to the file system from various sources
  """
  use Properties, otp_app: :reaper

  @type url :: String.t()
  @type dataset_id :: String.t()
  @type filename :: String.t()
  @type headers :: list()
  @type protocol :: list()

  @callback handle?(url()) :: boolean()
  @callback slurp(url(), dataset_id(), headers(), protocol()) :: {:file, filename()} | no_return()

  @implementations [
    Reaper.DataSlurper.Http,
    Reaper.DataSlurper.Sftp,
    Reaper.DataSlurper.S3
  ]

  getter(:download_dir, generic: true, default: "")

  def slurp(url, dataset_id, headers \\ %{}, protocol \\ nil, action \\ "GET", body \\ "") do
    @implementations
    |> Enum.find(&handle?(&1, url))
    |> apply(:slurp, [url, dataset_id, headers, protocol, action, body])
  end

  def determine_filename(dataset_id) do
    download_dir() <> dataset_id
  end

  defp handle?(implementation, url) do
    apply(implementation, :handle?, [url])
  end
end

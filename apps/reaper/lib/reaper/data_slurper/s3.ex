defmodule Reaper.DataSlurper.S3 do
  @moduledoc """
  Downloads files directly from the platform internal S3-compatible object store.
  """
  @behaviour Reaper.DataSlurper
  alias ExAws.S3
  alias Reaper.DataSlurper
  require Logger

  @impl DataSlurper
  def handle?(url), do: String.starts_with?(url, "s3")

  @impl DataSlurper
  def slurp("s3://" <> location = _url, ingestion_id, headers \\ [], _protocol \\ nil, _action \\ nil, _body \\ "") do
    filename = DataSlurper.determine_filename(ingestion_id)
    [bucket, key] = String.split(location, "/", parts: 2)

    bucket
    |> S3.download_file(key, filename)
    |> download_s3_file_request(headers)
    |> case do
      {:ok, _} -> {:file, filename}
      {:error, err} -> raise "Error downloading file for #{bucket}/#{key}: #{err}"
    end
  end

  def download_s3_file_request(s3_download_struct, %{"x-scos-amzn-s3-region": region}) do
    ExAws.request(s3_download_struct, region: region)
  end

  def download_s3_file_request(s3_download_struct, _headers) do
    ExAws.request(s3_download_struct)
  end
end

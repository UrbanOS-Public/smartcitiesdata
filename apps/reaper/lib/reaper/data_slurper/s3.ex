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
  def slurp("s3://" <> location = _url, dataset_id, _headers \\ [], _protocol \\ nil) do
    filename = DataSlurper.determine_filename(dataset_id)
    [bucket, key] = String.split(location, "/", parts: 2)

    bucket
    |> S3.download_file(key, filename)
    |> ExAws.request()
    |> case do
      {:ok, _} -> {:file, filename}
      {:error, err} -> raise "Error downloading file for #{bucket}/#{key}: #{err}"
    end
  end
end

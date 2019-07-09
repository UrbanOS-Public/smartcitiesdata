defmodule Reaper.HostedFileProcessor do
  @moduledoc """
  Downloads files for hosted datasets from their source and stores them in an S3 bucket
  """
  require Logger
  alias ExAws.S3

  alias Reaper.{
    UrlBuilder,
    DataSlurper
  }

  @doc """
  Process a hosted dataset
  """
  def process(config) do
    filename = get_filename(config)

    _something =
      config
      |> UrlBuilder.build()
      |> DataSlurper.slurp(config.dataset_id, config.sourceHeaders, config.protocol)
      |> upload(filename)

    # record_last_fetched_timestamp
  end

  defp upload({:file, path}, filename) do
    path
    |> S3.Upload.stream_file()
    |> S3.upload(bucket_name(), filename)
    |> ExAws.request()
  end

  defp bucket_name, do: Application.get_env(:reaper, :hosted_file_bucket)

  defp get_filename(config), do: "#{config.orgName}/#{config.dataName}.#{config.sourceFormat}"
end

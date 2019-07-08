defmodule Reaper.HostedFileProcessor do
  @moduledoc """
  Downloads files for hosted datasets from their source and stores them in an S3 bucket
  """
  require Logger

  alias Reaper.{
    ReaperConfig,
    UrlBuilder,
    DataSlurper,
    S3Uploader
  }

  @doc """
  Process a hosted dataset
  """
  def process(config) do
    _something =
      config
      |> UrlBuilder.build()
      |> DataSlurper.slurp(config.dataset_id, config.sourceHeaders, config.protocol)
      |> upload(config)

    # record_last_fetched_timestamp
  end

  def upload({:file, path}, config), do: S3Uploader.upload(path, config)
end

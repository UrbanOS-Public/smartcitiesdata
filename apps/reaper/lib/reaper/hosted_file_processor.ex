defmodule Reaper.HostedFileProcessor do
  @moduledoc """
  Downloads files for hosted datasets from their source and stores them in an S3 bucket
  """
  require Logger
  import SmartCity.Event, only: [file_upload: 0]
  alias SmartCity.Event.FileUpload
  alias ExAws.S3

  alias Reaper.{
    UrlBuilder,
    DataSlurper,
    Persistence
  }

  @doc """
  Process a hosted dataset
  """
  def process(config) do
    filename = get_filename(config)
    generated_time_stamp = DateTime.utc_now()

    _something =
      config
      |> UrlBuilder.build()
      |> DataSlurper.slurp(config.dataset_id, config.sourceHeaders, config.protocol)
      |> upload(filename)

    send_event(config, filename)
    record_last_fetched_timestamp(config.dataset_id, generated_time_stamp)
  rescue
    error ->
      Logger.error("Unable to continue processing dataset #{inspect(config)} - Error #{inspect(error)}")

      reraise error, __STACKTRACE__
  after
    config.dataset_id
    |> DataSlurper.determine_filename()
    |> File.rm()
  end

  defp upload({:file, path}, filename) do
    path
    |> S3.Upload.stream_file()
    |> S3.upload(bucket_name(), filename)
    |> ExAws.request()
  end

  def send_event(config, filename) do
    {:ok, file_upload} =
      FileUpload.new(%{
        dataset_id: config.dataset_id,
        mime_type: MIME.type(config.sourceFormat),
        bucket: bucket_name(),
        key: filename
      })

    Logger.debug(fn -> "#{__MODULE__} : Sending event to event stream : #{inspect(file_upload)}" end)
    Brook.Event.send(file_upload(), :reaper, file_upload)
  end

  defp bucket_name, do: Application.get_env(:reaper, :hosted_file_bucket)

  defp get_filename(config), do: "#{config.orgName}/#{config.dataName}.#{config.sourceFormat}"

  defp record_last_fetched_timestamp(dataset_id, timestamp) do
    Persistence.record_last_fetched_timestamp(dataset_id, timestamp)
  end
end

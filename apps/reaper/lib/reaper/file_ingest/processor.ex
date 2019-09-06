defmodule Reaper.FileIngest.Processor do
  @moduledoc """
  Downloads files for hosted datasets from their source and stores them in an S3 bucket
  """
  require Logger
  import SmartCity.Event, only: [file_upload: 0]
  alias SmartCity.HostedFile
  alias ExAws.S3

  alias Reaper.{
    UrlBuilder,
    DataSlurper,
    Persistence
  }

  @doc """
  Process a hosted dataset
  """
  def process(dataset) do
    filename = get_filename(dataset)
    generated_time_stamp = DateTime.utc_now()

    _something =
      dataset
      |> UrlBuilder.build()
      |> DataSlurper.slurp(dataset.id, dataset.technical.sourceHeaders, dataset.technical.protocol)
      |> upload(filename)

    send_event(dataset, filename)
    record_last_fetched_timestamp(dataset.id, generated_time_stamp)
  rescue
    error ->
      Logger.error("Unable to continue processing dataset #{inspect(dataset)} - Error #{inspect(error)}")

      reraise error, __STACKTRACE__
  after
    dataset.id
    |> DataSlurper.determine_filename()
    |> File.rm()
  end

  defp upload({:file, path}, filename) do
    path
    |> S3.Upload.stream_file()
    |> S3.upload(bucket_name(), filename)
    |> ExAws.request()
  end

  def send_event(dataset, filename) do
    {:ok, file_upload} =
      HostedFile.new(%{
        dataset_id: dataset.id,
        mime_type: MIME.type(dataset.technical.sourceFormat),
        bucket: bucket_name(),
        key: filename
      })

    Logger.debug(fn -> "#{__MODULE__} : Sending event to event stream : #{inspect(file_upload)}" end)
    Brook.Event.send(file_upload(), :reaper, file_upload)
  end

  defp bucket_name, do: Application.get_env(:reaper, :hosted_file_bucket)

  defp get_filename(%SmartCity.Dataset{
         technical: %{orgName: org_name, dataName: data_name, sourceFormat: source_format}
       }) do
    "#{org_name}/#{data_name}.#{source_format}"
  end

  defp record_last_fetched_timestamp(dataset_id, timestamp) do
    Persistence.record_last_fetched_timestamp(dataset_id, timestamp)
  end
end

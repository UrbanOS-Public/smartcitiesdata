defmodule Reaper.FileIngest.Processor do
  @moduledoc """
  Downloads files for hosted datasets from their source and stores them in an S3 bucket
  """
  require Logger
  import SmartCity.Event, only: [file_ingest_end: 0]
  alias SmartCity.HostedFile
  alias ExAws.S3
  alias Providers.Helpers.Provisioner

  alias Reaper.{
    UrlBuilder,
    DataSlurper
  }

  @instance Reaper.Application.instance()

  @doc """
  Process a hosted dataset
  """
  def process(%SmartCity.Dataset{} = unprovisioned_dataset) do
    dataset = Provisioner.provision(unprovisioned_dataset)
    filename = get_filename(dataset)

    dataset
    |> UrlBuilder.build()
    |> DataSlurper.slurp(dataset.id, dataset.technical.sourceHeaders, dataset.technical.protocol)
    |> upload(filename)

    send_event(dataset, filename)
  rescue
    error ->
      Logger.error("Unable to continue processing dataset #{inspect(unprovisioned_dataset)} - Error #{inspect(error)}")

      reraise error, __STACKTRACE__
  after
    unprovisioned_dataset.id
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
        mime_type: dataset.technical.sourceFormat,
        bucket: bucket_name(),
        key: filename
      })

    Logger.debug(fn -> "#{__MODULE__} : Sending event to event stream : #{inspect(file_upload)}" end)
    Brook.Event.send(@instance, file_ingest_end(), :reaper, file_upload)
  end

  defp bucket_name, do: Application.get_env(:reaper, :hosted_file_bucket)

  defp get_filename(%SmartCity.Dataset{
         technical: %{orgName: org_name, dataName: data_name, sourceFormat: source_format}
       }) do
    extension =
      source_format
      |> MIME.extensions()
      |> hd()

    "#{org_name}/#{data_name}.#{extension}"
  end
end

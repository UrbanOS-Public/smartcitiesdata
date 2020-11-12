defmodule Odo.FileProcessor do
  @moduledoc """
  Transforms supported geo-spatial data file from one supported type
  to another, uploads the new file to the cloud object store, and
  updates the data pipeline to be aware that the new file type is available.
  """
  use Properties, otp_app: :odo

  require Logger
  import SmartCity.Event, only: [file_ingest_start: 0, file_ingest_end: 0, error_file_ingest: 0]
  use Retry
  alias ExAws.S3
  alias SmartCity.{Helpers, HostedFile}

  @instance_name Odo.instance_name()

  getter(:retry_delay, generic: true)
  getter(:retry_backoff, generic: true)

  def process(%Odo.ConversionMap{
        bucket: bucket,
        original_key: original_key,
        converted_key: converted_key,
        download_path: download_path,
        converted_path: converted_path,
        conversion: conversion,
        dataset_id: dataset_id
      }) do
    send_file_ingest_event(dataset_id, bucket, converted_key, file_ingest_start())
    start_time = DateTime.utc_now()

    conversion_result =
      retry with: linear_backoff(retry_delay(), retry_backoff()) |> Stream.take(5) do
        with :ok <- download(bucket, original_key, download_path),
             :ok <- convert(download_path, converted_path, conversion),
             :ok <- upload(bucket, converted_path, converted_key),
             :ok <- send_file_ingest_event(dataset_id, bucket, converted_key, file_ingest_end()) do
          :ok
        end
      after
        :ok ->
          Odo.MetricsRecorder.record_file_conversion_metrics(dataset_id, original_key, true, start_time)
          Logger.info("File uploaded for dataset #{dataset_id} to #{bucket}/#{converted_key}")
          :ok
      else
        {:error, reason} ->
          Odo.MetricsRecorder.record_file_conversion_metrics(dataset_id, original_key, false, start_time)
          explanation = "File upload failed for dataset #{dataset_id}: #{reason}"

          Brook.Event.send(@instance_name, error_file_ingest(), :odo, %{
            dataset_id: dataset_id,
            bucket: bucket,
            key: original_key
          })

          Logger.warn(explanation)
          {:error, explanation}
      end

    cleanup_files([download_path, converted_path])

    conversion_result
  end

  defp download(bucket, key, path) do
    bucket
    |> S3.download_file(key, path)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, err} -> {:error, "Error downloading file for #{bucket}/#{key}: #{err}"}
    end
  end

  defp convert(source, destination, conversion) do
    from = String.split(source, "/") |> List.last()
    to = String.split(destination, "/") |> List.last()

    with {:ok, converted_data} <- conversion.(source),
         :ok <- File.write(destination, converted_data) do
      :ok
    else
      {:error, err} ->
        {:error, "Unable to convert #{from} to #{to} for #{source}: #{err}"}
    end
  end

  defp upload(bucket, path, key) do
    path
    |> S3.Upload.stream_file()
    |> S3.upload(bucket, key)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, err} -> {:error, "Unable to upload file #{bucket}/#{key}: #{err}"}
    end
  end

  defp send_file_ingest_event(dataset_id, bucket, key, event_type) do
    new_mime =
      key
      |> String.split(".")
      |> List.last()
      |> Helpers.mime_type()

    {:ok, event} = HostedFile.new(%{dataset_id: dataset_id, bucket: bucket, key: key, mime_type: new_mime})

    Brook.Event.send(@instance_name, event_type, :odo, event)
  end

  defp cleanup_files(files) do
    Enum.each(files, &File.rm!/1)
  rescue
    File.Error ->
      Logger.warn("File removal failed")
  end
end

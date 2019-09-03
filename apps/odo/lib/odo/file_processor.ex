defmodule Odo.FileProcessor do
  @moduledoc """
  Transforms supported geo-spatial data file from one supported type
  to another, uploads the new file to the cloud object store, and
  updates the data pipeline to be aware that the new file type is available.
  """
  require Logger
  import SmartCity.Event, only: [file_upload: 0]
  use Retry
  alias ExAws.S3
  alias SmartCity.HostedFile

  def process(%{
        bucket: bucket,
        original_key: original_key,
        converted_key: converted_key,
        download_path: download_path,
        converted_path: converted_path,
        conversion: conversion,
        id: id
      }) do
    conversion_result =
      retry with: linear_backoff(retry_delay(), retry_backoff()) |> Stream.take(5) do
        with :ok <- download(bucket, original_key, download_path),
             :ok <- convert(download_path, converted_path, conversion),
             :ok <- upload(bucket, converted_path, converted_key),
             :ok <- send_file_upload_event(id, bucket, converted_key) do
          :ok
        end
      after
        :ok ->
          Logger.info("File uploaded for dataset #{id} to #{bucket}/#{converted_key}")
          :ok
      else
        {:error, reason} ->
          explanation = "File upload failed for dataset #{id}: #{reason}"
          Brook.Event.send("error:#{file_upload()}", :odo, %{dataset_id: id, bucket: bucket, key: original_key})
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

  defp send_file_upload_event(id, bucket, key) do
    new_mime =
      key
      |> String.split(".")
      |> List.last()
      |> HostedFile.type()

    {:ok, event} = HostedFile.new(%{dataset_id: id, bucket: bucket, key: key, mime_type: new_mime})

    Brook.Event.send(file_upload(), :odo, event)
  end

  defp cleanup_files(files) do
    Enum.each(files, &File.rm!/1)
  rescue
    File.Error ->
      Logger.warn("File removal failed")
  end

  defp record_metrics(success, start_time, file_event) do
    success_value = if success, do: 1, else: 0
    duration = Time.diff(Time.utc_now(), start_time, :millisecond)

    labels = [
      dataset_id: file_event.dataset_id,
      file: file_event.key
    ]

    @metric_collector.record_metrics(
      [
        @metric_collector.gauge_metric(success_value, "file_process_success", labels),
        @metric_collector.gauge_metric(duration, "file_process_duration", labels)
      ],
      "odo"
    )
  end

  defp working_dir(), do: Application.get_env(:odo, :working_dir)
  defp retry_delay(), do: Application.get_env(:odo, :retry_delay)
  defp retry_backoff(), do: Application.get_env(:odo, :retry_backoff)
end

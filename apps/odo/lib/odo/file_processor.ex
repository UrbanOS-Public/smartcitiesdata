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

  def process(%HostedFile{} = file_event) do
    source_type = get_extension(file_event.key)
    convert = get_conversion_map(source_type)
    download_destination = "#{working_dir()}/#{file_event.dataset_id}.#{convert.from}"
    converted_file_path = "#{working_dir()}/#{file_event.dataset_id}.#{convert.to}"
    new_key = String.replace_suffix(file_event.key, source_type, convert.to)

    conversion_result =
      retry with: linear_backoff(1000, 10) |> Stream.take(5) do
        with :ok <- download(file_event.bucket, file_event.key, download_destination),
             :ok <- convert(download_destination, converted_file_path, convert),
             :ok <- upload(file_event.bucket, converted_file_path, new_key),
             :ok <- send_file_upload_event(file_event.dataset_id, file_event.bucket, new_key, convert.to) do
          :ok
        end
      after
        :ok ->
          Logger.info("File uploaded for dataset #{file_event.dataset_id} to #{file_event.bucket}/#{new_key}")
          :ok
      else
        {:error, reason} ->
          explanation = "File upload failed for dataset #{file_event.dataset_id}: #{reason}"
          Logger.warn(explanation)
          {:error, explanation}
      end

    cleanup_files([download_destination, converted_file_path])
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

  defp convert(source, destination, converter) do
    with {:ok, converted_data} <- converter.function.(source),
         :ok <- File.write(destination, converted_data) do
      :ok
    else
      {:error, err} ->
        {:error, "Unable to convert #{converter.from} to #{converter.to} for #{source}: #{err}"}
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

  defp send_file_upload_event(id, bucket, key, type) do
    new_type = HostedFile.type(type)
    {:ok, event} = HostedFile.new(%{dataset_id: id, bucket: bucket, key: key, mime_type: new_type})

    Brook.Event.send(file_upload(), "odo", event)
  end

  defp get_extension(file) do
    file
    |> String.split(".")
    |> List.last()
  end

  defp get_conversion_map(type) do
    case type do
      shapefile when shapefile in ["shapefile", "shp", "zip"] ->
        %{from: "shapefile", to: "geojson", function: &Geomancer.geo_json/1}

      _ ->
        raise "Unable to convert file; unsupported type"
    end
  end

  defp cleanup_files(files) do
    Enum.each(files, &File.rm!/1)
  rescue
    File.Error ->
      Logger.warn("File removal failed")
  end

  defp working_dir(), do: Application.get_env(:odo, :working_dir)
end

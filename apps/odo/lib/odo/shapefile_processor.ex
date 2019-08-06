defmodule Odo.ShapefileProcessor do
  @moduledoc """
  Transforms Shapefiles into GeoJson, uploads the GeoJson to S3, and
  updates the data pipeline to be aware that the new file type is available.
  """
  require Logger
  alias ExAws.S3
  import SmartCity.Events, only: [file_uploaded: 0]
  alias SmartCity.Events.FileUploaded

  def process(%{"dataset_id" => id, "bucket" => bucket, "key" => key}) do
    download_destination = "#{working_dir()}/#{id}.zip"
    geo_json_path = "#{working_dir()}/#{id}.geojson"
    new_key = String.replace_suffix(key, "zip", "geojson")

    download_file(bucket, key, download_destination)
    convert_to_geo_json(download_destination, geo_json_path)
    upload(bucket, geo_json_path, new_key)

    send_file_uploaded_event(id, bucket, new_key)
    cleanup_files([download_destination, geo_json_path])
  end

  defp download_file(bucket, key, path) do
    S3.download_file(bucket, key, path)
    |> ExAws.request()
    |> case do
      {:ok, :done} -> :ok
      {:error, err} -> raise "Error downloading file for #{bucket}/#{key}: #{err}"
    end
  end

  defp convert_to_geo_json(source, destination) do
    with {:ok, geo_json} <- Geomancer.geo_json(source),
         :ok <- File.write(destination, geo_json) do
      :ok
    else
      {:error, err} ->
        raise "Unable to convert shapefile into geojson for #{source}: #{err}"
    end
  end

  defp upload(bucket, path, key) do
    path
    |> S3.Upload.stream_file()
    |> S3.upload(bucket, key)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, err} -> raise "Unable to upload geojson file #{bucket}/#{key}: #{err}"
    end
  end

  defp send_file_uploaded_event(id, bucket, key) do
    Brook.send_event(file_uploaded(), %FileUploaded{
      dataset_id: id,
      mime_type: "application/geojson",
      bucket: bucket,
      key: key
    })
    |> case do
      :ok ->
        Logger.info("File uploaded for dataset #{id} to #{bucket}/#{key}")
        :ok

      {:error, reason} ->
        Logger.warn("File upload failed for dataset #{id}")
    end
  end

  defp cleanup_files(files) do
    Enum.each(files, &File.rm!/1)
  end

  defp working_dir(), do: Application.get_env(:odo, :working_dir)
end

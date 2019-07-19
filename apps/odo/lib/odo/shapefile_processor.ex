defmodule Odo.ShapefileProcessor do
  @moduledoc """
  Transforms Shapefiles into GeoJson, uploads the GeoJson to S3, and
  updates the data pipeline to be aware that the new file type is available.
  """
  use Retry
  alias ExAws.S3
  import Stream
  import Logger
  @s3_bucket "hosted-dataset-files"

  def process(dataset) do
    id = dataset.id
    org = dataset.technical.orgName
    data_name = dataset.technical.dataName

    source = "#{org}/#{data_name}.shapefile"
    download_destination = "#{download_dir()}/#{org}/#{data_name}.zip"
    converted_local_path = "#{download_dir()}/#{org}/#{data_name}.geojson"
    converted_s3_path = "#{org}/#{data_name}.geojson"

    File.mkdir!("#{download_dir()}/#{org}")

    retry with: cycle([1000]) |> take(60) do
      S3.download_file(@s3_bucket, source, download_destination)
      |> ExAws.request()
    after
      {:ok, :done} -> :ok
    else
      {:error, :enoent} -> Logger.error("File doesn't exist for #{id} at #{@s3_bucket}/#{source}")
      {:error, err} -> Logger.error("Error downloading file for #{id}: #{err}")
    end

    geo_json =
      case Geomancer.geo_json(download_destination) do
        {:ok, geojson} -> geojson
        {:error, err} -> Logger.error("Unable to convert shapefile into geojson for #{id}: #{err}")
      end

    File.write!(converted_local_path, geo_json)

    {:ok, _} = upload(converted_local_path, converted_s3_path)

    Redix.command!(:redix, ["SADD", "smart_city:filetypes:#{id}", "geojson"])

    File.rm!(download_destination)
    File.rm!(converted_local_path)
  end

  defp upload(path, s3_filename) do
    path
    |> S3.Upload.stream_file()
    |> S3.upload(@s3_bucket, s3_filename)
    |> ExAws.request()
  end

  defp download_dir(), do: Application.get_env(:odo, :download_dir)
end

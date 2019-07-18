defmodule Odo.ShapefileProcessor do
  @moduledoc """
  Transforms Shapefiles into GeoJson, uploads the GeoJson to S3, and
  updates the data pipeline to be aware that the new file type is available.
  """
  alias ExAws.S3

  def(process(opts)) do
    result =
      retry with: constant_backoff(100) |> Stream.take(10) do
        # Get File from s3
        # S3.download_file("env-hosted-dataset-file", "orgName/dataname.sourceFormat", "orgName/dataname.sourceFormat")
        # |> ExAws.request #=> {:ok, :done}
      end

    # Geomance to GeoJSON
    # File must have a .zip ext
    # Geomancer.geo_json(input_file)

    # Upload to S3

    # Update DiscoveryAPI format types
  end
end

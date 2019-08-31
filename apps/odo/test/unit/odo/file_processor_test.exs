defmodule Odo.Unit.FileProcessorTest do
  import SmartCity.Event, only: [file_upload: 0]
  import ExUnit.CaptureLog
  use ExUnit.Case
  use Placebo
  alias SmartCity.HostedFile

  test "converts shapefile to geojson" do
    allow(ExAws.request(any()), return: {:ok, :done})
    allow(Geomancer.geo_json(any()), return: {:ok, :geo_json_data})
    allow(File.write(any(), any()), return: :ok, meck_options: [:passthrough])
    allow(File.rm!(any()), return: :ok, meck_options: [:passthrough])
    allow(Brook.Event.send(file_upload(), any(), any()), return: :ok, meck_options: [:passthrough])

    conversion_map = %{
      bucket: "hosted-files",
      original_key: "my-org/my-dataset.shapefile",
      converted_key: "my-org/my-dataset.geojson",
      download_path: "tmp/111.shapefile",
      converted_path: "tmp/111.geojson",
      conversion: &Geomancer.geo_json/1,
      id: 111
    }

    {:ok, expected_event} =
      HostedFile.new(%{
        dataset_id: 111,
        mime_type: "application/geo+json",
        bucket: "hosted-files",
        key: "my-org/my-dataset.geojson"
      })

    assert Odo.FileProcessor.process(conversion_map) == :ok
    assert_called(Brook.Event.send(file_upload(), :odo, expected_event), once())
    assert_called(File.rm!("tmp/111.shapefile"), once())
    assert_called(File.rm!("tmp/111.geojson"), once())
  end

  test "outputs error after unsuccessful retries" do
    allow(ExAws.request(any()),
      return: {:error, :econnrefused},
      meck_options: [:passthrough]
    )

    shapefile_attempt = %{
      bucket: "hosted-files",
      original_key: "my-org/my-dataset.zip",
      converted_key: "my-org/my-dataset.geojson",
      download_path: "tmp/113.shapefile",
      converted_path: "tmp/113.geojson",
      conversion: &Geomancer.geo_json/1,
      id: 113
    }

    assert capture_log(fn ->
             assert Odo.FileProcessor.process(shapefile_attempt) ==
                      {:error,
                       "File upload failed for dataset 113: Error downloading file for hosted-files/my-org/my-dataset.zip: econnrefused"}
           end) =~ "econnrefused"
  end
end

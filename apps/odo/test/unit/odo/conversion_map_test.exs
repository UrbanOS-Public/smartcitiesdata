defmodule Odo.Unit.ConversionMapTest do
  use ExUnit.Case
  alias SmartCity.HostedFile

  test "produces valid conversion instructions" do
    {:ok, file_event} =
      HostedFile.new(%{
        dataset_id: 111,
        mime_type: "application/zip",
        bucket: "hosted-files",
        key: "my-org/my-dataset.shapefile"
      })

    expected =
      {:ok,
       %Odo.ConversionMap{
         bucket: "hosted-files",
         original_key: "my-org/my-dataset.shapefile",
         converted_key: "my-org/my-dataset.geojson",
         download_path: "/tmp/111.shapefile",
         converted_path: "/tmp/111.geojson",
         conversion: &Geomancer.geo_json/1,
         dataset_id: 111
       }}

    result = Odo.ConversionMap.generate(file_event)

    assert result == expected
  end

  test "returns error on unsupported file type" do
    {:ok, bad_event} =
      HostedFile.new(%{
        dataset_id: 112,
        mime_type: "application/zip",
        bucket: "hosted-files",
        key: "my-org/my-dataset.foo"
      })

    expected = {:error, "Unable to convert file; unsupported type"}

    result = Odo.ConversionMap.generate(bad_event)

    assert result == expected
  end
end

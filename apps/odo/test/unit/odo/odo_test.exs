defmodule Odo.Unit.OdoTest do
  import SmartCity.Event, only: [file_upload: 0]
  use ExUnit.Case
  use Placebo
  alias SmartCity.Event.FileUpload

  test "stuff" do
    allow(ExAws.request(any()), return: {:ok, :done})
    allow(Geomancer.geo_json(any()), return: {:ok, :geo_json_data})
    allow(File.write(any(), any()), return: :ok, meck_options: [:passthrough])
    allow(File.rm!(any()), return: :ok, meck_options: [:passthrough])
    allow(Brook.Event.send(file_upload(), any(), any()), return: :ok, meck_options: [:passthrough])

    {:ok, file_event} =
      FileUpload.new(%{
        dataset_id: 111,
        mime_type: "application/zip",
        bucket: "hosted-files",
        key: "my-org/my-dataset.shapefile"
      })

    assert Odo.FileProcessor.process(file_event) == :ok

    {:ok, expected_event} =
      FileUpload.new(%{
        dataset_id: 111,
        mime_type: "application/geo+json",
        bucket: "hosted-files",
        key: "my-org/my-dataset.geojson"
      })

    assert_called(Brook.Event.send(file_upload(), "odo", expected_event), once())
    assert_called(File.rm!("tmp/111.shapefile"), once())
    assert_called(File.rm!("tmp/111.geojson"), once())
  end

  test "raises an error on unsupported file type" do
    {:ok, bad_event} =
      FileUpload.new(%{
        dataset_id: 112,
        mime_type: "application/zip",
        bucket: "hosted-files",
        key: "my-org/my-dataset.foo"
      })

    assert_raise RuntimeError, "Unable to convert file; unsupported type", fn ->
      Odo.FileProcessor.process(bad_event)
    end
  end
end

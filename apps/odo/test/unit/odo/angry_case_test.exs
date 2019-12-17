defmodule Odo.AngryCaseTest do
  use ExUnit.Case
  use Placebo

  import SmartCity.Event, only: [file_ingest_end: 0, error_file_ingest: 0]
  alias ExAws.S3
  alias SmartCity.HostedFile

  test "Individual task failures do not stop others" do
    start_supervised!(Odo.TestEventHandler)

    # Application.put_env(:odo, :working_dir, "test/support")

    File.cp!("test/support/my-data.shapefile", "/tmp/123.shapefile")

    id = 123
    data_name = "my-data"
    org = "my-org"
    bucket = "unit-test-cloud-storage"

    {:ok, good_event} =
      HostedFile.new(%{
        dataset_id: id,
        bucket: bucket,
        key: "#{org}/#{data_name}.shapefile",
        mime_type: "application/zip"
      })

    expected_good_event = %{
      author: "odo",
      data: %SmartCity.HostedFile{
        bucket: bucket,
        dataset_id: id,
        key: "#{org}/#{data_name}.geojson",
        mime_type: "application/geo+json",
        version: "0.1"
      },
      forwarded: false,
      type: "file:ingest:start"
    }

    {:ok, bad_event} =
      HostedFile.new(%{
        dataset_id: 113,
        bucket: bucket,
        key: "#{org}/doesnt_exist.shapefile",
        mime_type: "application/zip"
      })

    expected_bad_event = %{
      author: "odo",
      data: %{
        "bucket" => bucket,
        "dataset_id" => 113,
        "key" => "#{org}/doesnt_exist.shapefile"
      },
      forwarded: false,
      type: "error:file:ingest"
    }

    allow(ExAws.request(any()), return: {:ok, :there})

    Brook.Event.send(Odo.event_stream_instance(), file_ingest_end(), :odo, bad_event)
    Brook.Event.send(Odo.event_stream_instance(), file_ingest_end(), :odo, good_event)

    SmartCity.TestHelper.eventually(fn ->
      events = Odo.TestEventHandler.get_events()

      assert expected_good_event in events
      assert Enum.member?(events, expected_good_event)
      assert expected_bad_event in events
    end)
  end
end

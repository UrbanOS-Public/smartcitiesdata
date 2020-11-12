defmodule Odo.AngryCaseTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :odo

  import SmartCity.Event, only: [file_ingest_end: 0]
  alias SmartCity.HostedFile
  alias Odo.Support.TestEventHandler

  @instance_name Odo.instance_name()

  getter(:working_dir, generic: true, default: :unset)

  test "Individual task failures do not stop others" do
    start_supervised!(TestEventHandler)

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

    old_path = working_dir()

    try do
      {:ok, dir_path} = Temp.mkdir(Temp.path())
      File.cp!("test/support/my-data.shapefile", "#{dir_path}/123.shapefile")
      Application.put_env(:odo, :working_dir, dir_path)

      Brook.Event.send(@instance_name, file_ingest_end(), :odo, bad_event)
      Brook.Event.send(@instance_name, file_ingest_end(), :odo, good_event)

      SmartCity.TestHelper.eventually(fn ->
        events = TestEventHandler.get_events()

        assert Enum.member?(events, expected_good_event)
        assert Enum.member?(events, expected_bad_event)
      end)
    after
      if old_path != :unset do
        Application.put_env(:odo, :working_dir, old_path)
      else
        Application.delete_env(:odo, :working_dir)
      end
    end
  end
end

defmodule Odo.Integration.OdoTest do
  use ExUnit.Case
  use Divo
  import SmartCity.TestHelper
  import SmartCity.Event, only: [file_ingest_end: 0, error_file_ingest: 0]
  alias ExAws.S3
  alias SmartCity.HostedFile

  @kafka_broker Application.get_env(:odo, :kafka_broker)
  @org "my-org"
  @bucket "kdp-cloud-storage"

  setup_all do
    "#{File.cwd!()}/test/support/my-data.shapefile"
    |> S3.Upload.stream_file()
    |> S3.upload(@bucket, "#{@org}/my-data.shapefile")
    |> ExAws.request()

    "#{File.cwd!()}/test/support/my-data2.shapefile"
    |> S3.Upload.stream_file()
    |> S3.upload(@bucket, "#{@org}/my-data2.shapefile")
    |> ExAws.request()
  end

  describe "error handling scenario" do
    setup do
      Temp.track!()
      Application.put_env(:odo, :working_dir, Temp.mkdir!())

      id = 112
      data_name = "my-data2"

      [id: id, data_name: data_name]
    end

    test "individual task failure does not stop others", %{id: id, data_name: data_name} do
      {:ok, good_event} =
        HostedFile.new(%{
          dataset_id: id,
          bucket: @bucket,
          key: "#{@org}/#{data_name}.shapefile",
          mime_type: "application/zip"
        })

      {:ok, bad_event} =
        HostedFile.new(%{
          dataset_id: 113,
          bucket: @bucket,
          key: "#{@org}/doesnt_exist.shapefile",
          mime_type: "application/zip"
        })

      Brook.Event.send(Odo.event_stream_instance(), file_ingest_end(), :odo, bad_event)
      Brook.Event.send(Odo.event_stream_instance(), file_ingest_end(), :odo, good_event)

      eventually(fn ->
        result_events =
          Elsa.Fetch.search_values(@kafka_broker, "event-stream", "file:ingest")
          |> Enum.to_list()
          |> Enum.filter(fn event ->
            String.contains?(event.value, "my-data2.geojson") || String.contains?(event.value, error_file_ingest())
          end)
          |> Enum.map(fn event -> Brook.Deserializer.deserialize(struct(Brook.Event), event.value) end)
          |> Enum.map(fn {:ok, value} -> value.data end)

        {:ok, expected_success} =
          HostedFile.new(%{
            dataset_id: 112,
            mime_type: "application/geo+json",
            bucket: @bucket,
            key: "#{@org}/#{data_name}.geojson"
          })

        expected_failure = %{"bucket" => @bucket, "dataset_id" => 113, "key" => "#{@org}/doesnt_exist.shapefile"}

        assert Enum.member?(result_events, expected_success) == true
        assert Enum.member?(result_events, expected_failure) == true
      end)
    end
  end
end

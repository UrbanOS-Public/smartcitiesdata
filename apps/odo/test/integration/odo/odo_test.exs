defmodule Odo.Integration.OdoTest do
  use ExUnit.Case
  use Divo
  import SmartCity.TestHelper
  import SmartCity.Event, only: [file_upload: 0]
  alias SmartCity.HostedFile

  @kafka_broker Application.get_env(:odo, :kafka_broker)
  @org "my-org"
  @bucket "hosted-dataset-files"

  describe "success scenario" do
    setup do
      Temp.track!()
      Application.put_env(:odo, :working_dir, Temp.mkdir!())

      id = 111
      data_name = "my-data"

      on_exit(fn ->
        File.rm!("test/support/minio_data/#{@bucket}/#{@org}/#{data_name}.geojson")
      end)

      [id: id, data_name: data_name]
    end

    test "retrieves, converts, and uploads supported file type", %{id: id, data_name: data_name} do
      {:ok, file_event} =
        HostedFile.new(%{
          dataset_id: id,
          bucket: @bucket,
          key: "#{@org}/#{data_name}.shapefile",
          mime_type: "application/zip"
        })

      new_key = "#{@org}/#{data_name}.geojson"

      Brook.Event.send(file_upload(), :odo, file_event)

      eventually(fn ->
        fileResp =
          ExAws.S3.get_object(@bucket, new_key)
          |> ExAws.request()

        assert {:ok, %{body: body}} = fileResp
        assert body != nil

        [actual_event] =
          Elsa.Fetch.search_values(@kafka_broker, "event-stream", "my-data.geojson")
          |> Enum.to_list()
          |> Enum.map(fn event -> Brook.Deserializer.deserialize(struct(Brook.Event), event.value) end)
          |> Enum.map(fn {:ok, value} -> value.data end)

        actual_state = Brook.get_all_values!(:file_conversions)

        {:ok, expected_event} =
          HostedFile.new(%{
            dataset_id: id,
            mime_type: "application/geo+json",
            bucket: @bucket,
            key: new_key
          })

        assert actual_event == expected_event
        assert Enum.member?(actual_state, file_event) == false
      end)
    end
  end

  describe "error handling scenario" do
    setup do
      Temp.track!()
      Application.put_env(:odo, :working_dir, Temp.mkdir!())

      id = 112
      data_name = "my-data2"

      on_exit(fn ->
        File.rm!("test/support/minio_data/#{@bucket}/#{@org}/#{data_name}.geojson")
      end)

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

      Brook.Event.send(file_upload(), :odo, bad_event)
      Brook.Event.send(file_upload(), :odo, good_event)

      eventually(fn ->
        result_events =
          Elsa.Fetch.search_values(@kafka_broker, "event-stream", "file:upload")
          |> Enum.to_list()
          |> Enum.filter(fn event ->
            String.contains?(event.value, "my-data2.geojson") || String.contains?(event.value, "error:file:upload")
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

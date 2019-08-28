defmodule Odo.Integration.OdoTest do
  use ExUnit.Case
  use Divo
  import SmartCity.TestHelper
  import SmartCity.Event, only: [file_upload: 0]
  alias SmartCity.HostedFile

  @kafka_broker Application.get_env(:odo, :kafka_broker)

  setup do
    id = 111
    org = "my-org"
    data_name = "my-data"
    bucket = "hosted-dataset-files"

    on_exit(fn ->
      File.rm!("test/support/minio_data/hosted-dataset-files/#{org}/#{data_name}.geojson")
    end)

    [
      id: id,
      org: org,
      data_name: data_name,
      bucket: bucket
    ]
  end

  test "retrieves, converts, and uploads supported file type", %{id: id, org: org, data_name: data_name, bucket: bucket} do
    Temp.track!()
    Application.put_env(:odo, :working_dir, Temp.mkdir!())

    {:ok, file_event} =
      HostedFile.new(%{
        dataset_id: id,
        bucket: bucket,
        key: "#{org}/#{data_name}.shapefile",
        mime_type: "application/zip"
      })

    Brook.Event.send(file_upload(), "odo", file_event)

    new_key = "#{org}/#{data_name}.geojson"

    eventually(fn ->
      fileResp =
        ExAws.S3.get_object(bucket, new_key)
        |> ExAws.request()

      assert {:ok, %{body: body}} = fileResp
      assert body != nil

      actual_event =
        Elsa.Fetch.search_values(@kafka_broker, "event-stream", ".geojson")
        |> Enum.to_list()
        |> hd()
        |> (fn event -> Brook.Deserializer.deserialize(struct(Brook.Event), event.value) end).()
        |> (fn {:ok, value} -> value.data end).()

      actual_state = Brook.get_all_values!(:file_conversions)

      {:ok, expected_event} =
        HostedFile.new(%{
          dataset_id: id,
          mime_type: "application/geo+json",
          bucket: bucket,
          key: new_key
        })

      assert actual_event == expected_event
      assert Enum.member?(actual_state, file_event) == false
    end)
  end
end

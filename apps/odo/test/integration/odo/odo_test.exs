defmodule Odo.OdoTest do
  use ExUnit.Case
  use Divo
  import SmartCity.TestHelper
  import SmartCity.Event, only: [file_upload: 0]
  alias SmartCity.Event.FileUpload

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
      FileUpload.new(%{dataset_id: id, bucket: bucket, key: "#{org}/#{data_name}.zip", mime_type: "application/zip"})

    Brook.send_event(file_upload(), file_event)

    new_key = "#{org}/#{data_name}.geojson"

    eventually(fn ->
      fileResp =
        ExAws.S3.get_object(bucket, new_key)
        |> ExAws.request()

      assert {:ok, %{body: body}} = fileResp
      assert body != nil

      actual = Elsa.Fetch.search_values(@kafka_broker, "event-stream", ".geojson") |> Enum.to_list() |> hd()

      expected =
        Jason.encode!(FileUpload.new(%{
          dataset_id: id,
          mime_type: "application/geo+json",
          bucket: bucket,
          key: new_key
        }))

      assert actual.value == expected
    end)
  end

  # test "raises an error on unsupported file type", %{id: id, org: org, data_name: data_name, bucket: bucket} do
  #   Temp.track!()
  #   Application.put_env(:odo, :working_dir, Temp.mkdir!())

  #   {:ok, file_event} =
  #     FileUpload.new(%{dataset_id: id, bucket: bucket, key: "#{org}/#{data_name}.foo", mime_type: "application/zip"})

  #   Brook.send_event(file_upload(), file_event)

  #   assert_raise RuntimeError, "Unable to convert file; unsupported type", :process
  # end
end

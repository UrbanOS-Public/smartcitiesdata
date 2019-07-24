defmodule Odo.OdoTest do
  use ExUnit.Case
  use Divo
  require Logger
  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG
  alias ExAws.S3
  import SmartCity.TestHelper

  setup do
    id = 111
    org = "my-org"
    dataName = "my-data"
    bucket = "hosted-dataset-files"

    on_exit(fn ->
      File.rm!("test/support/minio_data/hosted-dataset-files/#{org}/#{dataName}.geojson")
    end)

    [
      id: id,
      org: org,
      dataName: dataName,
      bucket: bucket
    ]
  end

  test "happy path", %{id: id, org: org, dataName: dataName, bucket: bucket} do
    Temp.track!()
    Application.put_env(:odo, :download_dir, Temp.mkdir!())

    dataset =
      TDG.create_dataset(%{
        id: id,
        technical: %{
          sourceFormat: "shapefile",
          sourceType: "host",
          orgName: org,
          dataName: dataName
        }
      })

    SmartCity.Dataset.write(dataset)

    eventually(fn ->
      fileResp =
        ExAws.S3.get_object(bucket, "/#{org}/#{dataName}.geojson")
        |> ExAws.request()

      assert {:ok, %{body: body}} = fileResp
      assert body != nil

      assert {:ok, 1} = Redix.command(:redix, ["SISMEMBER", "smart_city:filetypes:#{id}", "geojson"])
    end)
  end
end

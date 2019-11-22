defmodule DiscoveryApi.Data.HostedFileTest do
  use ExUnit.Case
  use Divo
  use DiscoveryApi.DataCase
  alias SmartCity.Registry.Dataset
  alias DiscoveryApi.TestDataGenerator, as: TDG
  alias DiscoveryApi.Test.Helper

  require Logger

  @expected_checksum :crypto.hash(:md5, File.read!("test/integration/test-file.test")) |> Base.encode16()

  @dataset_id "123-123"
  @dataset_name "test_id"

  setup do
    Application.put_env(:ex_aws, :access_key_id, "testing_access_key")
    Application.put_env(:ex_aws, :secret_access_key, "testing_secret_key")

    Helper.wait_for_brook_to_be_ready()
    Redix.command!(:redix, ["FLUSHALL"])

    "test/integration/test-file.test"
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(Application.get_env(:discovery_api, :hosted_bucket), "test_org/#{@dataset_name}.geojson")
    |> ExAws.request!()

    "test/integration/test-file.test"
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(Application.get_env(:discovery_api, :hosted_bucket), "test_org/#{@dataset_name}.shp")
    |> ExAws.request!()

    :ok
  end

  @moduletag capture_log: true
  test "downloads a file with the geojson extension" do
    dataset_id = @dataset_id
    dataset_name = @dataset_name
    system_name = "not_saved"

    organization = Helper.create_persisted_organization(%{orgName: "test_org"})

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{systemName: system_name, orgId: organization.id, sourceType: "host", dataName: dataset_name}
      })

    Dataset.write(dataset)

    Patiently.wait_for!(
      fn -> download_and_checksum(organization.orgName, dataset.technical.dataName, "application/geo+json") == @expected_checksum end,
      dwell: 200,
      max_tries: 5
    )
  end

  @moduletag capture_log: true
  test "downloads a file with a custom mime type" do
    dataset_id = @dataset_id
    dataset_name = @dataset_name
    system_name = "not_saved"

    organization = Helper.create_persisted_organization(%{orgName: "test_org"})

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{systemName: system_name, orgId: organization.id, sourceType: "host", dataName: dataset_name}
      })

    Dataset.write(dataset)

    Patiently.wait_for!(
      fn -> download_and_checksum(organization.orgName, dataset.technical.dataName, "application/zip") == @expected_checksum end,
      dwell: 200,
      max_tries: 5
    )
  end

  @moduletag capture_log: true
  test "downloads a file with a explicit format" do
    dataset_id = @dataset_id
    dataset_name = @dataset_name
    system_name = "not_saved"

    organization = Helper.create_persisted_organization(%{orgName: "test_org"})

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{systemName: system_name, orgId: organization.id, sourceType: "host", dataName: dataset_name}
      })

    Dataset.write(dataset)

    Patiently.wait_for!(
      fn -> download_and_checksum_with_format(organization.orgName, dataset.technical.dataName, "shp") == @expected_checksum end,
      dwell: 200,
      max_tries: 5
    )
  end

  @moduletag capture_log: true
  test "unacceptable response if file with that type does not exist" do
    dataset_id = @dataset_id
    dataset_name = @dataset_name
    system_name = "not_saved"

    organization = Helper.create_persisted_organization(%{orgName: "test_org"})

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{systemName: system_name, orgId: organization.id, sourceType: "host", dataName: dataset_name}
      })

    Dataset.write(dataset)

    Patiently.wait_for!(
      fn ->
        %{status_code: status_code, body: _body} =
          "http://localhost:4000/api/v1/organization/#{organization.orgName}/dataset/#{dataset.technical.dataName}/download"
          |> HTTPoison.get!([{"Accept", "audio/ATRAC3"}])
          |> Map.from_struct()

        status_code == 406
      end,
      dwell: 200,
      max_tries: 5
    )
  end

  defp download_and_checksum(org_name, dataset_name, accept_header) do
    body =
      "http://localhost:4000/api/v1/organization/#{org_name}/dataset/#{dataset_name}/download"
      |> HTTPoison.get!([{"Accept", "#{accept_header}"}])
      |> Map.get(:body)

    if is_binary(body) do
      Logger.info("Got something: #{inspect(body)}")
      checksum = :crypto.hash(:md5, body) |> Base.encode16()

      checksum
    else
      Logger.info("Got something unexpected: #{body}")
      false
    end
  end

  defp download_and_checksum_with_format(org_name, dataset_name, format) do
    body =
      "http://localhost:4000/api/v1/organization/#{org_name}/dataset/#{dataset_name}/download?_format=#{format}"
      |> HTTPoison.get!()
      |> Map.get(:body)

    if is_binary(body) do
      Logger.info("Got something: #{inspect(body)}")
      checksum = :crypto.hash(:md5, body) |> Base.encode16()

      checksum
    else
      Logger.info("Got something unexpected: #{body}")
      false
    end
  end
end

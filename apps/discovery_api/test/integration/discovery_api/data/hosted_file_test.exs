defmodule DiscoveryApi.Data.HostedFileTest do
  use ExUnit.Case
  use Divo, services: [:redis, :presto, :metastore, :postgres, :minio]
  alias SmartCity.{Dataset, Organization}
  alias SmartCity.TestDataGenerator, as: TDG

  require Logger

  @expected_checksum :crypto.hash(:md5, File.read!("test/integration/test-file.test")) |> Base.encode16()

  @dataset_id "test_id"

  setup do
    Redix.command!(:redix, ["FLUSHALL"])

    "test/integration/test-file.test"
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(Application.get_env(:discovery_api, :hosted_bucket), "test_org/#{@dataset_id}.geojson")
    |> ExAws.request!()

    "test/integration/test-file.test"
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(Application.get_env(:discovery_api, :hosted_bucket), "test_org/#{@dataset_id}.tgz")
    |> ExAws.request!()

    :ok
  end

  @moduletag capture_log: true
  test "downloads a file with the geojson extension" do
    dataset_id = @dataset_id
    system_name = "not_saved"

    organization = TDG.create_organization(%{orgName: "test_org"})
    Organization.write(organization)

    dataset = TDG.create_dataset(%{id: dataset_id, technical: %{systemName: system_name, orgId: organization.id}})
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
    system_name = "not_saved"

    organization = TDG.create_organization(%{orgName: "test_org"})
    Organization.write(organization)

    dataset = TDG.create_dataset(%{id: dataset_id, technical: %{systemName: system_name, orgId: organization.id}})
    Dataset.write(dataset)

    Patiently.wait_for!(
      fn -> download_and_checksum(organization.orgName, dataset.technical.dataName, "application/shapefile") == @expected_checksum end,
      dwell: 200,
      max_tries: 5
    )
  end

  @moduletag capture_log: true
  test "unacceptable response if file with that type does not exist" do
    dataset_id = @dataset_id
    system_name = "not_saved"

    organization = TDG.create_organization(%{orgName: "test_org"})
    Organization.write(organization)

    dataset = TDG.create_dataset(%{id: dataset_id, technical: %{systemName: system_name, orgId: organization.id}})
    Dataset.write(dataset)

    Patiently.wait_for!(
      fn ->
        %{status_code: status_code, body: body} =
          "http://localhost:4000/api/v1/organization/#{organization.orgName}/dataset/#{dataset.technical.dataName}/download"
          |> HTTPoison.get!([{"Accept", "audio/ATRAC3, application/json"}])
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
      |> HTTPoison.get!([{"Accept", "#{accept_header}, application/json"}])
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

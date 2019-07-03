defmodule DiscoveryApi.Data.HostedFileTest do
  use ExUnit.Case
  use Divo, services: [:redis, :presto, :metastore, :postgres, :minio]
  alias SmartCity.{Dataset, Organization}
  alias SmartCity.TestDataGenerator, as: TDG

  require Logger

  @expected_checksum :crypto.hash(:md5, File.read!("test/integration/test-file.test")) |> Base.encode16

  @dataset_id "test_id"

  setup do
    Redix.command!(:redix, ["FLUSHALL"])

    "test/integration/test-file.test"
    |> ExAws.S3.Upload.stream_file
    |> ExAws.S3.upload(Application.get_env(:discovery_api, :hosted_bucket), "test_org/#{@dataset_id}.test")
    |> ExAws.request!

    :ok
  end

  @moduletag capture_log: true
  test "downloads a file" do
    dataset_id = @dataset_id
    system_name = "not_saved"

    organization = TDG.create_organization(%{orgName: "test_org"})
    Organization.write(organization)

    dataset = TDG.create_dataset(%{id: dataset_id, technical: %{systemName: system_name, orgId: organization.id}})
    Dataset.write(dataset)

    Patiently.wait_for!(
      fn -> download(organization.orgName, dataset.technical.dataName) == [] end,
      dwell: 2000,
      max_tries: 10
    )
  end

  defp download(org_name, dataset_name) do
    body =
      "http://localhost:4000/api/v1/organization/#{org_name}/dataset/#{dataset_name}/download"
      |> HTTPoison.get!([{"Accept", "application/json"}])
      |> Map.get(:body)

    if is_binary(body) do
      Logger.info("Got something: #{inspect body}")
      checksum = :crypto.hash(:md5, body) |> Base.encode16

      assert checksum == @expected_checksum
    else
      Logger.info("Got something unexpected: #{body}")
      false
    end
  end
end

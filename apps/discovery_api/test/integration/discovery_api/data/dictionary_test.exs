defmodule DiscoveryApi.Data.DictionaryTest do
  use ExUnit.Case
  use Divo, services: [:redis, :zookeeper, :kafka, :"ecto-postgres"]
  use DiscoveryApi.DataCase
  alias DiscoveryApi.TestDataGenerator, as: TDG
  alias SmartCity.Registry.Dataset
  alias DiscoveryApi.Test.Helper

  setup do
    Helper.wait_for_brook_to_be_ready()
    Redix.command!(:redix, ["FLUSHALL"])
    :ok
  end

  describe "/api/v1/dataset/dictionary" do
    test "returns not found when dataset does not exist" do
      %{status_code: status_code, body: body} =
        "http://localhost:4000/api/v1/dataset/non_existant_id/dictionary"
        |> HTTPoison.get!()

      result = Jason.decode!(body, keys: :atoms)
      assert status_code == 404
      assert result.message == "Not Found"
    end

    test "returns schema for provided dataset id" do
      schema = [%{name: "column_name", description: "column description", type: "string"}]
      organization = Helper.create_persisted_organization()

      dataset =
        TDG.create_dataset(%{
          business: %{description: "Bob had a horse and this is its data"},
          technical: %{orgId: organization.id, schema: schema}
        })

      Dataset.write(dataset)
      DiscoveryApi.Data.DatasetEventListener.handle_dataset(dataset)

      %{status_code: status_code, body: body} =
        "http://localhost:4000/api/v1/dataset/#{dataset.id}/dictionary"
        |> HTTPoison.get!()

      assert status_code == 200
      assert Jason.decode!(body, keys: :atoms) == schema
    end
  end
end

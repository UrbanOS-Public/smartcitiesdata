defmodule DiscoveryApi.Data.DictionaryTest do
  use ExUnit.Case
  use Placebo
  use DiscoveryApi.DataCase
  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Test.Helper
  import SmartCity.TestHelper
  import SmartCity.Event, only: [dataset_update: 0]

  @instance_name DiscoveryApi.instance_name()

  setup do
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
      allow(RaptorService.list_access_groups_by_dataset(any(), any()), return: %{access_groups: []})
      schema = [%{name: "column_name", description: "column description", type: "string"}]
      organization = Helper.create_persisted_organization()

      dataset =
        TDG.create_dataset(%{
          business: %{description: "Bob had a horse and this is its data"},
          technical: %{orgId: organization.id, schema: schema}
        })

      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

      eventually(fn ->
        %{status_code: status_code, body: body} =
          "http://localhost:4000/api/v1/dataset/#{dataset.id}/dictionary"
          |> HTTPoison.get!()

        assert status_code == 200
        assert Jason.decode!(body, keys: :atoms) == schema
      end)
    end
  end
end

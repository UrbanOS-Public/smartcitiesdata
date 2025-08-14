defmodule DiscoveryApiWeb.MetadataController.SchemaTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  alias DiscoveryApi.Test.Helper

  @moduletag timeout: 5000

  setup :verify_on_exit!
  setup :set_mox_from_context

  @dataset_id "123"

  describe "fetch schema" do
    test "retrieves limited fields for dataset schema from model", %{conn: conn} do
      schema = [
        %{
          description: "a number",
          name: "number",
          type: "integer",
          pii: "false",
          biased: "false",
          masked: "N/A",
          demographic: "None",
          subSchema: %{}
        },
        %{
          description: "a name",
          name: "name",
          type: "list",
          pii: "true",
          biased: "true",
          masked: "yes",
          demographic: "Other",
          itemType: "string"
        }
      ]

      model =
        Helper.sample_model(%{id: @dataset_id})
        |> Map.put(:schema, schema)

      stub(ModelMock, :get, fn dataset_id ->
        case dataset_id do
          @dataset_id -> model
          _ -> nil
        end
      end)

      actual = conn |> get("/api/v1/dataset/#{@dataset_id}/dictionary") |> json_response(200)

      expected = [
        %{"name" => "number", "type" => "integer", "description" => "a number", "subSchema" => %{}},
        %{"name" => "name", "type" => "list", "description" => "a name", "itemType" => "string"}
      ]

      assert expected == actual
    end

    test "returns 404 when dataset does not exist", %{conn: conn} do
      stub(ModelMock, :get, fn _dataset_id -> nil end)

      conn |> get("/api/v1/dataset/xyz123/dictionary") |> json_response(404)
    end
  end
end

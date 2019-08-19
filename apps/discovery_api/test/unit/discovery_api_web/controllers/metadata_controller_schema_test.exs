defmodule DiscoveryApiWeb.MetadataController.SchemaTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Data.Model

  @dataset_id "123"

  describe "fetch schema" do
    test "retrieves dataset schema from model", %{conn: conn} do
      model = Helper.sample_model(%{id: @dataset_id})

      allow(Model.get(@dataset_id), return: model)

      actual = conn |> get("/api/v1/dataset/#{@dataset_id}/dictionary") |> json_response(200)

      assert Helper.stringify_keys(model.schema) == actual
    end

    test "returns 404 when dataset does not exist", %{conn: conn} do
      expect(Model.get(any()), return: nil)

      conn |> get("/api/v1/dataset/xyz123/dictionary") |> json_response(404)
    end
  end
end

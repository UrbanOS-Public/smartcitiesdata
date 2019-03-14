defmodule DiscoveryApiWeb.DatasetDetailControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Test.Helper

  describe "fetch dataset detail" do
    test "retreives dataset from retriever", %{conn: conn} do
      dataset = Helper.sample_dataset()
      expect(DiscoveryApi.Data.Retriever.get_dataset(dataset.id), return: dataset)

      actual = conn |> get("/api/v1/dataset/#{dataset.id}") |> json_response(200)

      assert dataset.id == actual["id"]
      assert dataset.description == actual["description"]
      assert dataset.keywords == actual["keywords"]
      assert dataset.organization == actual["organization"]["name"]
    end

    test "returns 404", %{conn: conn} do
      expect(DiscoveryApi.Data.Retriever.get_dataset(any()), return: nil)

      conn |> get("/api/v1/dataset/xyz123") |> json_response(404)
    end
  end
end

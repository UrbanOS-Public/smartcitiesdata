defmodule DiscoveryApiWeb.DatasetDetailControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Test.Helper
  alias SmartCity.TestDataGenerator, as: TDG

  describe "fetch dataset detail" do
    test "retreives dataset + organization from retriever when organzation found", %{conn: conn} do
      dataset = Helper.sample_dataset()
      organization = TDG.create_organization(%{id: dataset.organization})

      expect(DiscoveryApi.Data.Dataset.get(dataset.id), return: dataset)
      expect(DiscoveryApi.Data.Organization.get(dataset.organization), return: {:ok, organization})

      actual = conn |> get("/api/v1/dataset/#{dataset.id}") |> json_response(200)

      assert %{
               "id" => dataset.id,
               "name" => dataset.title,
               "description" => dataset.description,
               "keywords" => dataset.keywords,
               "organization" => %{
                 "name" => organization.orgTitle,
                 "image" => organization.logoUrl,
                 "description" => organization.description,
                 "homepage" => organization.homepage
               },
               "sourceType" => dataset.sourceType,
               "sourceUrl" => dataset.sourceUrl
             } == actual
    end

    test "returns 500 if organization not found for various reasons", %{conn: conn} do
      dataset = Helper.sample_dataset()

      expect(DiscoveryApi.Data.Dataset.get(dataset.id), return: dataset)
      expect(DiscoveryApi.Data.Organization.get(dataset.organization), return: {:error, :whatever})

      conn |> get("/api/v1/dataset/#{dataset.id}") |> json_response(500)
    end

    test "returns 404", %{conn: conn} do
      expect(DiscoveryApi.Data.Dataset.get(any()), return: nil)

      conn |> get("/api/v1/dataset/xyz123") |> json_response(404)
    end
  end
end

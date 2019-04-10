defmodule DiscoveryApiWeb.DatasetDetailControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Test.Helper

  describe "fetch dataset detail" do
    test "retrieves dataset + organization from retriever when organization found", %{conn: conn} do
      dataset = Helper.sample_dataset()

      expect DiscoveryApi.Data.Dataset.get(dataset.id), return: dataset

      actual = conn |> get("/api/v1/dataset/#{dataset.id}") |> json_response(200)

      assert %{
               "id" => dataset.id,
               "name" => dataset.title,
               "description" => dataset.description,
               "keywords" => dataset.keywords,
               "organization" => %{
                 "name" => dataset.organizationDetails.orgTitle,
                 "image" => dataset.organizationDetails.logoUrl,
                 "description" => dataset.organizationDetails.description,
                 "homepage" => dataset.organizationDetails.homepage
               },
               "sourceType" => dataset.sourceType,
               "sourceUrl" => dataset.sourceUrl,
               "lastUpdatedDate" => nil,
               "contactName" => dataset.contactName,
               "contactEmail" => dataset.contactEmail,
               "license" => dataset.license,
               "rights" => dataset.rights,
               "homepage" => dataset.homepage,
               "spatial" => dataset.spatial,
               "temporal" => dataset.temporal,
               "publishFrequency" => dataset.publishFrequency,
               "conformsToUri" => dataset.conformsToUri,
               "describedByUrl" => dataset.describedByUrl,
               "describedByMimeType" => dataset.describedByMimeType,
               "parentDataset" => dataset.parentDataset,
               "issuedDate" => dataset.issuedDate,
               "language" => dataset.language,
               "referenceUrls" => dataset.referenceUrls,
               "categories" => dataset.categories,
               "modified" => dataset.modified
             } == actual
    end

    test "returns 404", %{conn: conn} do
      expect(DiscoveryApi.Data.Dataset.get(any()), return: nil)

      conn |> get("/api/v1/dataset/xyz123") |> json_response(404)
    end
  end
end

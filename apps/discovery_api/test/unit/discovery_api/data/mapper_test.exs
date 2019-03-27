defmodule DiscoveryApi.Data.MapperTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.Mapper

  setup do
    dataset = %SmartCity.Dataset{
      id: "myfancydata",
      business: %SmartCity.Dataset.Business{
        dataTitle: "my title",
        description: "description",
        modifiedDate: "The Date",
        orgTitle: "Organization 1",
        contactName: "Bob Jones",
        contactEmail: "bjones@example.com",
        license: "http://openlicense.org",
        keywords: ["key", "words"],
        homepage: "www.bad.com",
        rights: "some rights",
        spatial: "some space",
        temporal: "some temporal val",
        publishFrequency: "publish freq",
        conformsToUri: "some conform uri",
        describedByUrl: "some url for describe by",
        describedByMimeType: "some mime type (describe)",
        parentDataset: "parentDataset",
        issuedDate: "issueddate",
        language: "english or spanish or something",
        referenceUrls: ["a", "list", "of", "urls"],
        categories: ["things", "stuff", "other"]
      }
    }

    {:ok,
     %{
       dataset: dataset
     }}
  end

  describe "to_podms with all fields" do
    setup %{dataset: dataset} do
      result = Mapper.to_podms(dataset, "url")

      {:ok, %{result: result}}
    end

    test "Should map fields", %{dataset: dataset, result: result} do
      assert dataset.id == result["identifier"]
      assert dataset.business.dataTitle == result["title"]
      assert dataset.business.description == result["description"]
      assert dataset.business.keywords == result["keyword"]
      assert dataset.business.modifiedDate == result["modified"]
      assert dataset.business.orgTitle == result["publisher"]["name"]
      assert dataset.business.contactName == result["contactPoint"]["fn"]
      assert dataset.business.homepage == result["landingPage"]
      assert "mailto:" <> dataset.business.contactEmail == result["contactPoint"]["hasEmail"]
      assert dataset.business.license == result["license"]

      assert dataset.business.rights == result["rights"]
      assert dataset.business.spatial == result["spatial"]
      assert dataset.business.temporal == result["temporal"]
      assert dataset.business.publishFrequency == result["accrualPeriodicity"]
      assert dataset.business.conformsToUri == result["conformsTo"]
      assert dataset.business.describedByUrl == result["describedBy"]
      assert dataset.business.describedByMimeType == result["describedByType"]
      assert dataset.business.parentDataset == result["isPartOf"]
      assert dataset.business.issuedDate == result["issued"]
      assert dataset.business.language == result["language"]
      assert dataset.business.referenceUrls == result["references"]
      assert dataset.business.categories == result["theme"]
    end

    test "Should create distribution for json", %{dataset: dataset, result: result} do
      distribution = result["distribution"] |> Enum.find(fn dist -> dist["mediaType"] == "application/json" end)
      assert "url/api/v1/#{dataset.id}/download?_format=json" == distribution["accessURL"]
      assert "dcat:Distribution" == distribution["@type"]
    end

    test "Should create distribution for csv", %{dataset: dataset, result: result} do
      distribution = result["distribution"] |> Enum.find(fn dist -> dist["mediaType"] == "text/csv" end)
      assert "url/api/v1/#{dataset.id}/download?_format=csv" == distribution["accessURL"]
      assert "dcat:Distribution" == distribution["@type"]
    end
  end

  describe "to_podms with only required fields" do
    test "drops optional fields with nil value" do
      dataset = %SmartCity.Dataset{
        id: "myfancydata",
        business: %SmartCity.Dataset.Business{
          dataTitle: "my title",
          description: "description",
          modifiedDate: "The Date",
          orgTitle: "Organization 1",
          contactName: "Bob Jones",
          contactEmail: "bjones@example.com"
        }
      }

      result_keys =
        dataset
        |> Mapper.to_podms("url")
        |> Map.keys()
        |> Enum.sort()

      required_keys =
        [
          "@type",
          "title",
          "description",
          "modified",
          "publisher",
          "contactPoint",
          "identifier",
          "accessLevel",
          "distribution"
        ]
        |> Enum.sort()

      assert required_keys == result_keys
    end
  end
end

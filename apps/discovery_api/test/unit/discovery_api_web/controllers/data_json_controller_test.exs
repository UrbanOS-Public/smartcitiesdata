defmodule DiscoveryApiWeb.DataJsonControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper

  setup do
    model =
      Helper.sample_model(%{
        id: "myfancydata",
        name: "my name",
        title: "my title",
        description: "description",
        modifiedDate: "The Date",
        organization: "Organization 1",
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
        categories: ["things", "stuff", "other"],
        accessLevel: "non-public"
      })

    {:ok,
     %{
       model: model
     }}
  end

  describe "to_podms with all fields" do
    setup %{conn: conn, model: model} do
      allow Model.get_all(), return: [model]
      [result] = conn |> get("/api/v1/data_json") |> json_response(200) |> Map.get("dataset")

      {:ok, %{result: result}}
    end

    test "Should map fields", %{model: model, result: result} do
      assert model.id == result["identifier"]
      assert model.title == result["title"]
      assert model.description == result["description"]
      assert model.keywords == result["keyword"]
      assert model.modifiedDate == result["modified"]
      assert model.organization == result["publisher"]["name"]
      assert model.contactName == result["contactPoint"]["fn"]
      assert "mailto:" <> model.contactEmail == result["contactPoint"]["hasEmail"]
      assert model.homepage == result["landingPage"]
      assert model.license == result["license"]
      assert(model.rights == result["rights"])
      assert model.accessLevel == result["accessLevel"]

      assert model.spatial == result["spatial"]
      assert model.temporal == result["temporal"]
      assert model.publishFrequency == result["accrualPeriodicity"]
      assert model.conformsToUri == result["conformsTo"]
      assert model.describedByUrl == result["describedBy"]
      assert model.describedByMimeType == result["describedByType"]
      assert model.parentDataset == result["isPartOf"]
      assert model.issuedDate == result["issued"]
      assert model.language == result["language"]
      assert model.referenceUrls == result["references"]
      assert model.categories == result["theme"]
    end

    test "Should create distribution for json", %{model: model, result: result} do
      distribution = result["distribution"] |> Enum.find(fn dist -> dist["mediaType"] == "application/json" end)

      assert "https://data.tests.example.com/api/v1/dataset/#{model.id}/download?_format=json" ==
               distribution["accessURL"]

      assert "dcat:Distribution" == distribution["@type"]
    end

    test "Should create distribution for csv", %{model: model, result: result} do
      distribution = result["distribution"] |> Enum.find(fn dist -> dist["mediaType"] == "text/csv" end)

      assert "https://data.tests.example.com/api/v1/dataset/#{model.id}/download?_format=csv" ==
               distribution["accessURL"]

      assert "dcat:Distribution" == distribution["@type"]
    end
  end

  describe "to_podms with only required fields" do
    test "drops optional fields with nil value", %{conn: conn} do
      model = %Model{
        id: "myfancydata",
        title: "my title",
        description: "description",
        modifiedDate: "The Date",
        organization: "Organization 1",
        contactName: "Bob Jones",
        contactEmail: "bjones@example.com",
        license: "The License"
      }

      allow Model.get_all(), return: [model]

      result_keys =
        conn
        |> get("/api/v1/data_json")
        |> json_response(200)
        |> Map.get("dataset")
        |> List.first()
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
          "distribution",
          "license"
        ]
        |> Enum.sort()

      assert required_keys == result_keys
    end
  end
end

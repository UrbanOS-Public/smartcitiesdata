defmodule DiscoveryApiWeb.MultipleMetadataController.DataJsonTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper

  setup do
    public_model =
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
        accessLevel: "public",
        private: false
      })

    private_model =
      Helper.sample_model(%{
        accessLevel: "non-public",
        private: true
      })

    {:ok,
     %{
       models: [private_model, public_model]
     }}
  end

  describe "GET with all fields" do
    setup %{conn: conn, models: [_private_model, public_model] = models} do
      allow Model.get_all(), return: models
      results = conn |> get("/api/v1/data_json") |> json_response(200) |> Map.get("dataset")

      {:ok, %{model: public_model, results: results}}
    end

    test "only a single dataset (the public one) is returned", %{results: results} do
      assert 1 == Enum.count(results)
    end

    test "only the public dataset is exposed", %{results: [result | _]} do
      assert "public" == result["accessLevel"]
    end

    test "maps fields of interest", %{model: model, results: [result | _]} do
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

    test "correctly includes configured hostname for json distribution", %{model: model, results: [result | _]} do
      distribution = result["distribution"] |> Enum.find(fn dist -> dist["mediaType"] == "application/json" end)

      assert "http://data.tests.example.com/api/v1/dataset/#{model.id}/download?_format=json" ==
               distribution["accessURL"]

      assert "dcat:Distribution" == distribution["@type"]
    end

    test "correctly includes configured hostname for csv distribution", %{model: model, results: [result | _]} do
      distribution = result["distribution"] |> Enum.find(fn dist -> dist["mediaType"] == "text/csv" end)

      assert "http://data.tests.example.com/api/v1/dataset/#{model.id}/download?_format=csv" ==
               distribution["accessURL"]

      assert "dcat:Distribution" == distribution["@type"]
    end
  end

  describe "GET with only required fields" do
    test "drops optional fields with nil value", %{conn: conn} do
      model = %Model{
        id: "myfancydata",
        title: "my title",
        description: "description",
        modifiedDate: "The Date",
        organization: "Organization 1",
        contactName: "Bob Jones",
        contactEmail: "bjones@example.com",
        license: "The License",
        private: false
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

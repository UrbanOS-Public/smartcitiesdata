defmodule DiscoveryApiWeb.DataJsonControllerTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Services.DataJsonService

  @moduletag timeout: 5000

  setup :verify_on_exit!
  setup :set_mox_from_context

  setup do
    # Stub PersistenceMock to return empty metrics for all dataset stats
    stub(PersistenceMock, :get_many_with_keys, fn _keys ->
      # Return empty map - no metrics data available
      %{}
    end)

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
        rights: "",
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
        private: false,
        sourceType: "ingest"
      })

    private_model =
      Helper.sample_model(%{
        accessLevel: "non-public",
        private: true
      })

    remote_model = Helper.sample_model(%{sourceType: "remote"})

    on_exit(fn ->
      DataJsonService.delete_data_json()
    end)

    %{models: [private_model, public_model, remote_model]}
  end

  describe "GET with all fields" do
    setup %{conn: conn, models: models} do
      # Set mocks global for this describe block so they work across processes
      set_mox_global()
      
      # DataJson calls Model.get_all() directly, not through dependency injection
      # So we need to use :meck to mock the Model module
      try do
        :meck.new(Model, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(Model, :get_all, fn -> models end)
      
      data_json = conn |> get("/api/v1/data_json") |> json_response(200) |> Map.get("dataset")

      on_exit(fn ->
        try do
          :meck.unload(Model)
        catch
          :error, _ -> :ok
        end
      end)

      %{models: models, data_json: data_json}
    end

    test "only a single dataset (the public one) is returned", %{data_json: data_json} do
      assert 1 == Enum.count(data_json)
    end

    test "does not return non-public datasets", %{data_json: data_json} do
      refute Enum.any?(data_json, fn dataset -> dataset["accessLevel"] == "non-public" end)
    end

    test "language is a list", %{data_json: [dataset | _]} do
      assert is_list(dataset["language"]) == true
    end

    test "removes optional fields with blanks from results", %{data_json: [dataset | _]} do
      assert dataset["rights"] == nil
    end

    test "never returns accrualPeriodicity", %{data_json: [dataset | _]} do
      # Decision was made to not return it since the values are not valid according to PODMS
      assert dataset["accrualPeriodicity"] == nil
    end

    test "never returns temporal", %{data_json: [dataset | _]} do
      # Decision was made to not return it since the values are not valid according to PODMS
      assert dataset["temporal"] == nil
    end

    test "only the public dataset is exposed", %{data_json: [dataset | _]} do
      assert "public" == dataset["accessLevel"]
    end

    test "maps fields of interest", %{models: models, data_json: [dataset | _]} do
      model = get_public_ingest_model(models)

      assert model.id == dataset["identifier"]
      assert model.title == dataset["title"]
      assert model.description == dataset["description"]
      assert model.keywords == dataset["keyword"]
      assert model.modifiedDate == dataset["modified"]
      assert model.organization == dataset["publisher"]["name"]
      assert model.contactName == dataset["contactPoint"]["fn"]
      assert "mailto:" <> model.contactEmail == dataset["contactPoint"]["hasEmail"]
      assert model.homepage == dataset["landingPage"]
      assert model.license == dataset["license"]
      assert model.accessLevel == dataset["accessLevel"]
      assert model.spatial == dataset["spatial"]
      assert model.conformsToUri == dataset["conformsTo"]
      assert model.describedByUrl == dataset["describedBy"]
      assert model.describedByMimeType == dataset["describedByType"]
      assert model.parentDataset == dataset["isPartOf"]
      assert model.issuedDate == dataset["issued"]
      assert [model.language] == dataset["language"]
      assert model.referenceUrls == dataset["references"]
      assert model.categories == dataset["theme"]
    end

    test "correctly includes configured hostname for json distribution", %{models: models, data_json: [dataset | _]} do
      model = get_public_ingest_model(models)

      distribution = dataset["distribution"] |> Enum.find(fn dist -> dist["mediaType"] == "application/json" end)

      assert "https://data.tests.example.com/api/v1/dataset/#{model.id}/download?_format=json" ==
               distribution["accessURL"]

      assert "dcat:Distribution" == distribution["@type"]
    end

    test "correctly includes configured hostname for csv distribution", %{models: models, data_json: [dataset | _]} do
      model = get_public_ingest_model(models)

      distribution = dataset["distribution"] |> Enum.find(fn dist -> dist["mediaType"] == "text/csv" end)

      assert "https://data.tests.example.com/api/v1/dataset/#{model.id}/download?_format=csv" ==
               distribution["accessURL"]

      assert "dcat:Distribution" == distribution["@type"]
    end
  end

  describe "GET with only required fields" do
    setup do
      # Set mocks global for this describe block too
      set_mox_global()
      :ok
    end
    
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

      # Use :meck for Model since DataJson doesn't use dependency injection
      try do
        :meck.new(Model, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(Model, :get_all, fn -> [model] end)
      
      on_exit(fn ->
        try do
          :meck.unload(Model)
        catch
          :error, _ -> :ok
        end
      end)

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

  defp get_public_ingest_model(models) do
    Enum.find(models, fn model -> model.private == false and model.sourceType == "ingest" end)
  end
end

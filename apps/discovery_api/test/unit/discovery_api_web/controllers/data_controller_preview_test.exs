defmodule DiscoveryApiWeb.DataController.PreviewTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  alias DiscoveryApiWeb.Utilities.JsonFieldDecoder

  setup :verify_on_exit!
  setup :set_mox_from_context

  @dataset_id "1234-4567-89101"
  @system_name "foobar__company_data"

  describe "preview dataset data" do
    setup do
      model =
        Helper.sample_model(%{
          id: @dataset_id,
          systemName: @system_name,
          private: false,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          schema: [
            %{name: "id", type: "integer"},
            %{name: "json_encoded", type: "json"}
          ]
        })

      # Mock the prestige session creation
      stub(PrestigeMock, :new_session, fn _opts -> "mock_session" end)
      
      stub(ModelMock, :get, fn dataset_id when dataset_id == @dataset_id -> model end)
      {:ok, %{model: model}}
    end

    test "preview controller returns data from preview service", %{conn: conn, model: model} do
      list_of_maps = [
        %{"id" => Faker.UUID.v4(), "json_encoded" => "{\"json_encoded\": \"tony\"}"},
        %{"id" => Faker.UUID.v4(), "json_encoded" => "{\"json_encoded\": \"andy\"}"},
        %{"id" => Faker.UUID.v4(), "json_encoded" => "{\"json_encoded\": \"smith\"}"}
      ]

      schema = model.schema
      encoded_maps = Enum.map(list_of_maps, &JsonFieldDecoder.decode_one_datum(schema, &1))

      list_of_columns = ["id", "json_encoded"]

      expected = %{"data" => encoded_maps, "meta" => %{"columns" => list_of_columns}}

      expect(PrestoServiceMock, :preview, fn _url, system_name, _schema -> 
        assert system_name == @system_name
        list_of_maps 
      end)
      expect(PrestoServiceMock, :preview_columns, fn _url -> list_of_columns end)

      actual = conn |> put_req_header("accept", "application/json") |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end

    test "preview controller does not return any metadata columns", %{conn: conn, model: model} do
      list_of_maps = [
        %{
          "id" => Faker.UUID.v4(),
          "_ingestion_id" => "will",
          "_extraction_id" => "be",
          "os_partition" => "removed",
          "json_encoded" => "{\"json_encoded\": \"tony\"}",
          "other" => "foo"
        },
        %{
          "id" => Faker.UUID.v4(),
          "_ingestion_id" => "will",
          "_extraction_id" => "be",
          "os_partition" => "removed",
          "json_encoded" => "{\"json_encoded\": \"andy\"}"
        },
        %{
          "id" => Faker.UUID.v4(),
          "_ingestion_id" => "will",
          "_extraction_id" => "be",
          "os_partition" => "removed",
          "json_encoded" => "{\"json_encoded\": \"smith\"}"
        }
      ]

      schema = model.schema
      encoded_maps = Enum.map(list_of_maps, &JsonFieldDecoder.decode_one_datum(schema, &1))

      list_of_columns = ["id", "json_encoded", "other"]

      expected = %{"data" => encoded_maps, "meta" => %{"columns" => list_of_columns}}

      expect(PrestoServiceMock, :preview, fn _url, system_name, _schema -> 
        assert system_name == @system_name
        list_of_maps 
      end)
      expect(PrestoServiceMock, :preview_columns, fn _url -> list_of_columns end)

      actual = conn |> put_req_header("accept", "application/json") |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end

    test "preview controller returns an empty list for an existing dataset with no data", %{conn: conn} do
      list_of_columns = ["id", "json_encoded"]
      expected = %{"data" => [], "meta" => %{"columns" => list_of_columns}}

      expect(PrestoServiceMock, :preview, fn _url, system_name, _schema -> 
        assert system_name == @system_name
        [] 
      end)
      expect(PrestoServiceMock, :preview_columns, fn _url -> list_of_columns end)
      actual = conn |> put_req_header("accept", "application/json") |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end

    test "preview controller returns _SOMETHING_ when table does not exist", %{conn: conn} do
      expected = %{"data" => [], "meta" => %{"columns" => []}}

      stub(PrestoServiceMock, :preview_columns, fn _url -> [] end)
      stub(PrestoServiceMock, :preview, fn _url, _system_name, _schema -> 
        raise Prestige.Error, message: "Test error" 
      end)
      actual = conn |> put_req_header("accept", "application/json") |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end
  end

  describe "fetch geojson dataset" do
    test "retrieves geojson dataset with bounding box", %{conn: conn} do
      dataset_name = "the_dataset"
      dataset_id = "the_dataset_id"

      schema = [
        %{name: "id", type: "integer"},
        %{name: "name", type: "string"}
      ]

      model =
        Helper.sample_model(%{
          id: dataset_id,
          name: dataset_name,
          sourceFormat: "geojson",
          systemName: dataset_name,
          schema: schema
        })

      # Mock the prestige session creation
      stub(PrestigeMock, :new_session, fn _opts -> "mock_session" end)
      
      stub(ModelMock, :get, fn id when id == dataset_id -> model end)

      stub(PrestoServiceMock, :preview, fn _url, name, schema_param ->
        assert name == dataset_name
        assert schema_param == schema
        [
          %{"feature" => "{\"geometry\": { \"coordinates\": [[0, 0], [0, 1]] }}"},
          %{"feature" => "{\"geometry\": { \"coordinates\": [[1, 0]] }}"},
          %{"feature" => "{\"geometry\": { \"coordinates\": [[1, 1]] }}"},
          %{"feature" => "{\"geometry\": { \"coordinates\": [[0, 1]] }}"}
        ]
      end)

      expect(PrestoServiceMock, :preview_columns, fn _url -> ["feature"] end)

      expected = %{
        "type" => "FeatureCollection",
        "name" => model.name,
        "bbox" => [0, 0, 1, 1],
        "features" => [
          %{"geometry" => %{"coordinates" => [[0, 0], [0, 1]]}},
          %{"geometry" => %{"coordinates" => [[1, 0]]}},
          %{"geometry" => %{"coordinates" => [[1, 1]]}},
          %{"geometry" => %{"coordinates" => [[0, 1]]}}
        ]
      }

      actual =
        conn
        |> put_req_header("accept", "application/geo+json")
        |> get("/api/v1/dataset/#{dataset_id}/preview")
        |> json_response(200)

      assert actual == expected
    end

    test "retrieves geojson dataset with no bounding box when coordinates list is empty", %{
      conn: conn
    } do
      dataset_name = "the_dataset"
      dataset_id = "the_dataset_id"

      model =
        Helper.sample_model(%{
          id: dataset_id,
          name: dataset_name,
          sourceFormat: "geojson",
          systemName: dataset_name
        })

      # Mock the prestige session creation
      stub(PrestigeMock, :new_session, fn _opts -> "mock_session" end)
      
      stub(ModelMock, :get, fn id when id == dataset_id -> model end)

      stub(PrestoServiceMock, :preview, fn _url, name, _schema ->
        assert name == dataset_name
        [
          %{"feature" => "{\"geometry\": { \"coordinates\": [] }}"}
        ]
      end)

      expect(PrestoServiceMock, :preview_columns, fn _url -> ["feature"] end)

      expected = %{
        "type" => "FeatureCollection",
        "name" => model.name,
        "features" => [
          %{"geometry" => %{"coordinates" => []}}
        ]
      }

      actual =
        conn
        |> put_req_header("accept", "application/geo+json")
        |> get("/api/v1/dataset/#{dataset_id}/preview")
        |> json_response(200)

      assert actual == expected
    end
  end
end

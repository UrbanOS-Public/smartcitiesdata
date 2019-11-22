defmodule DiscoveryApiWeb.DataController.PreviewTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApiWeb.Utilities.JsonFieldDecoder

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

      allow(Model.get(model.id), return: model)
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

      expect(PrestoService.preview(any(), @system_name), return: list_of_maps)
      expect(PrestoService.preview_columns(any(), @system_name), return: list_of_columns)

      actual = conn |> put_req_header("accept", "application/json") |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end

    test "preview controller returns an empty list for an existing dataset with no data", %{conn: conn} do
      list_of_columns = ["id", "json_encoded"]
      expected = %{"data" => [], "meta" => %{"columns" => list_of_columns}}

      expect(PrestoService.preview(any(), @system_name), return: [])
      expect(PrestoService.preview_columns(any(), @system_name), return: list_of_columns)
      actual = conn |> put_req_header("accept", "application/json") |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end

    test "preview controller returns _SOMETHING_ when table does not exist", %{conn: conn} do
      expected = %{"data" => [], "meta" => %{"columns" => []}}

      allow PrestoService.preview_columns(any(), any()), return: []
      allow PrestoService.preview(any(), any()), exec: fn _, _ -> raise Prestige.Error, message: "Test error" end
      actual = conn |> put_req_header("accept", "application/json") |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end
  end

  describe "fetch geojson dataset" do
    test "retrieves geojson dataset with bounding box", %{conn: conn} do
      dataset_name = "the_dataset"
      dataset_id = "the_dataset_id"

      model =
        Helper.sample_model(%{
          id: dataset_id,
          name: dataset_name,
          sourceFormat: "geojson",
          systemName: dataset_name,
          schema: [
            %{name: "id", type: "integer"},
            %{name: "name", type: "string"}
          ]
        })

      allow(Model.get(dataset_id), return: model)

      allow(DiscoveryApi.Services.PrestoService.preview(any(), dataset_name),
        return: [
          %{"feature" => "{\"geometry\": { \"coordinates\": [[0, 0], [0, 1]] }}"},
          %{"feature" => "{\"geometry\": { \"coordinates\": [[1, 0]] }}"},
          %{"feature" => "{\"geometry\": { \"coordinates\": [[1, 1]] }}"},
          %{"feature" => "{\"geometry\": { \"coordinates\": [[0, 1]] }}"}
        ]
      )

      expect(PrestoService.preview_columns(any(), dataset_name), return: ["feature"])

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

      allow(Model.get(dataset_id), return: model)

      allow(DiscoveryApi.Services.PrestoService.preview(any(), dataset_name),
        return: [
          %{"feature" => "{\"geometry\": { \"coordinates\": [] }}"}
        ]
      )

      expect(PrestoService.preview_columns(any(), dataset_name), return: ["feature"])

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

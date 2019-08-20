defmodule DiscoveryApiWeb.DataController.PreviewTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Services.PrestoService

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
            %{description: "a number", name: "id", type: "integer"},
            %{description: "a number", name: "name", type: "string"}
          ]
        })

      allow(Model.get(model.id), return: model)
      :ok
    end

    test "preview controller returns data from preview service", %{conn: conn} do
      list_of_maps = [
        %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
        %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
        %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)}
      ]

      encoded_maps =
        list_of_maps
        |> Jason.encode!()
        |> Jason.decode!()

      list_of_columns = ["id", "name"]

      expected = %{"data" => encoded_maps, "meta" => %{"columns" => list_of_columns}}

      expect(PrestoService.preview(@system_name), return: list_of_maps)
      expect(PrestoService.preview_columns(@system_name), return: list_of_columns)

      actual = conn |> put_req_header("accept", "application/json") |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end

    test "preview controller returns an empty list for an existing dataset with no data", %{conn: conn} do
      list_of_columns = ["id", "name"]
      expected = %{"data" => [], "meta" => %{"columns" => list_of_columns}}

      expect(PrestoService.preview(@system_name), return: [])
      expect(PrestoService.preview_columns(@system_name), return: list_of_columns)
      actual = conn |> put_req_header("accept", "application/json") |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

      assert expected == actual
    end

    test "preview controller returns _SOMETHING_ when table does not exist", %{conn: conn} do
      expected = %{"data" => [], "meta" => %{"columns" => []}}

      allow PrestoService.preview_columns(any()), return: []
      allow PrestoService.preview(any()), exec: fn _ -> raise Prestige.Error, message: "Test error" end
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
            %{description: "a number", name: "id", type: "integer"},
            %{description: "a number", name: "name", type: "string"}
          ]
        })

      allow(Model.get(dataset_id), return: model)

      allow(DiscoveryApi.Services.PrestoService.preview(dataset_name),
        return: [
          %{"feature" => "{\"geometry\": { \"coordinates\": [[0, 0], [0, 1]] }}"},
          %{"feature" => "{\"geometry\": { \"coordinates\": [[1, 0]] }}"},
          %{"feature" => "{\"geometry\": { \"coordinates\": [[1, 1]] }}"},
          %{"feature" => "{\"geometry\": { \"coordinates\": [[0, 1]] }}"}
        ]
      )

      expect(PrestoService.preview_columns(dataset_name), return: ["feature"])

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

      allow(DiscoveryApi.Services.PrestoService.preview(dataset_name),
        return: [
          %{"feature" => "{\"geometry\": { \"coordinates\": [] }}"}
        ]
      )

      expect(PrestoService.preview_columns(dataset_name), return: ["feature"])

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

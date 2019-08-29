defmodule DiscoveryApiWeb.DataController.DownloadTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  import Checkov
  import SmartCity.TestHelper
  alias DiscoveryApi.Data.{Model, SystemNameCache}
  alias DiscoveryApi.Services.PrestoService

  @dataset_id "1234-4567-89101"
  @system_name "foobar__company_data"
  @org_name "org1"
  @data_name "data1"

  setup do
    model =
      Helper.sample_model(%{
        id: @dataset_id,
        systemName: @system_name,
        name: @data_name,
        private: false,
        lastUpdatedDate: nil,
        queries: 7,
        downloads: 9,
        organizationDetails: %{
          orgName: @org_name
        },
        schema: [
          %{name: "id", type: "integer"},
          %{name: "name", type: "string"}
        ]
      })

    allow(SystemNameCache.get(@org_name, @data_name), return: @dataset_id)
    allow(Model.get(@dataset_id), return: model)

    allow(PrestoService.preview_columns(@system_name),
      return: ["id", "name"]
    )

    allow(Prestige.execute("select * from #{@system_name}", rows_as_maps: true),
      return: [%{"id" => 1, "name" => "Joe"}, %{"id" => 2, "name" => "Robby"}]
    )

    allow(Redix.command!(any(), any()), return: :does_not_matter)

    :ok
  end

  describe "fetching csv data with array of integers" do
    test "returns flattened array as string in single column in CSV format", %{conn: conn} do
      dataset_id = "pedro"
      url = "/api/v1/dataset/#{dataset_id}/download"

      model =
        Helper.sample_model(%{
          id: dataset_id,
          systemName: "#{@org_name}__paco",
          name: "paco",
          private: false,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          organizationDetails: %{
            orgName: @org_name
          },
          schema: [
            %{name: "number", type: "integer"},
            %{name: "number", type: "integer"}
          ]
        })

      allow(SystemNameCache.get(@org_name, model.name), return: dataset_id)
      allow(Model.get(dataset_id), return: model)

      allow(PrestoService.preview_columns(model.systemName),
        return: ["id", "int_array"]
      )

      allow(Prestige.execute("select * from #{model.systemName}", rows_as_maps: true),
        return: [%{"id" => 1, "int_array" => [2, 3, 4]}]
      )

      allow(Prestige.prefetch(any()),
        return: [%{"id" => "1", "int_array" => [2, 3, 4]}]
      )

      allow(Redix.command!(any(), any()), return: :does_not_matter)

      actual = conn |> get(url) |> response(200)

      assert "id,int_array\n1,\"2,3,4\"\n" == actual
    end

    test "returns json fields as valid json", %{conn: conn} do
      dataset_id = "stanislav"
      url = "/api/v1/dataset/#{dataset_id}/download"

      model =
        Helper.sample_model(%{
          id: dataset_id,
          systemName: "#{@org_name}__stan",
          name: "stan",
          private: false,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          organizationDetails: %{
            orgName: @org_name
          },
          schema: [
            %{name: "feature", type: "json"}
          ]
        })

      allow(SystemNameCache.get(@org_name, model.name), return: dataset_id)
      allow(Model.get(dataset_id), return: model)

      allow(PrestoService.preview_columns(model.systemName),
        return: ["feature"]
      )

      allow(Prestige.execute("select * from #{model.systemName}", rows_as_maps: true),
        return: [%{"feature" => "{\"geometry\":{\"coordinates\":[0,1]}}"}]
      )

      allow(Redix.command!(any(), any()), return: :does_not_matter)

      actual = conn |> put_req_header("accept", "application/geo+json") |> get(url) |> response(200)

      expected = %{
        "type" => "FeatureCollection",
        "name" => "#{@org_name}__stan",
        "features" => [
          %{
            "geometry" => %{
              "coordinates" => [0, 1]
            }
          }
        ],
        "bbox" => [0, 1, 0, 1]
      }

      assert expected == actual |> Jason.decode!()
    end
  end

  describe "metrics" do
    data_test "increments dataset download count when user requests download", %{conn: conn} do
      conn
      |> get(url)
      |> response(200)

      eventually(fn -> assert_called(Redix.command!(:redix, ["INCR", "smart_registry:downloads:count:#{@dataset_id}"])) end)

      where(
        url: [
          "/api/v1/dataset/1234-4567-89101/download?_format=csv",
          "/api/v1/organization/org1/dataset/data1/download?_format=csv",
          "/api/v1/dataset/1234-4567-89101/download?_format=json",
          "/api/v1/organization/org1/dataset/data1/download?_format=json"
        ]
      )
    end

    data_test "does not increment dataset download count when ui requests download", %{conn: conn} do
      conn
      |> Plug.Conn.put_req_header("origin", "data.integration.tests.example.com")
      |> get(url)
      |> response(200)

      refute_called(Redix.command!(:redix, ["INCR", "smart_registry:downloads:count:#{@dataset_id}"]))

      where(
        url: [
          "/api/v1/dataset/1234-4567-89101/download?_format=csv",
          "/api/v1/organization/org1/dataset/data1/download?_format=csv",
          "/api/v1/dataset/1234-4567-89101/download?_format=json",
          "/api/v1/organization/org1/dataset/data1/download?_format=json"
        ]
      )
    end
  end
end

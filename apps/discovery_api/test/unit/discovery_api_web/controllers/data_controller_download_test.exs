defmodule DiscoveryApiWeb.DataController.DownloadTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  import Checkov
  import SmartCity.TestHelper
  alias DiscoveryApi.Data.{Model, SystemNameCache}
  alias DiscoveryApi.Services.PrestoService

  @moduletag timeout: 5000

  setup :verify_on_exit!
  setup :set_mox_from_context

  @system_name_cache Application.compile_env(:discovery_api, :system_name_cache)
  @model Application.compile_env(:discovery_api, :model)
  @presto_service Application.compile_env(:discovery_api, :presto_service)
  @prestige Application.compile_env(:discovery_api, :prestige)
  @prestige_result Application.compile_env(:discovery_api, :prestige_result)
  @redix Application.compile_env(:discovery_api, :redix_module)
  @metrics_service Application.compile_env(:discovery_api, :metrics_service)

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

    org_name = @org_name
    data_name = @data_name
    dataset_id = @dataset_id
    stub(@system_name_cache, :get, fn ^org_name, ^data_name -> dataset_id end)
    stub(@model, :get, fn ^dataset_id -> model end)

    stub(@presto_service, :preview_columns, fn _ ->
      ["id", "name"]
    end)

    stub(@prestige, :new_session, fn _ -> :connection end)
    
    stub(@prestige_result, :as_maps, fn {:ok, data} -> [data] end)

    stub(@redix, :command!, fn _, _ -> :does_not_matter end)
    
    stub(@metrics_service, :record_api_hit, fn _, _ -> :ok end)

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

      org_name = @org_name
      model_name = model.name
      stub(@system_name_cache, :get, fn ^org_name, ^model_name -> dataset_id end)
      stub(@model, :get, fn ^dataset_id -> model end)

      stub(@presto_service, :preview_columns, fn _ ->
        ["id", "int_array"]
      end)

      stub(@prestige, :stream!, fn _, _ -> Stream.map([%{"id" => 1, "int_array" => [2, 3, 4]}], &{:ok, &1}) end)

      stub(@redix, :command!, fn _, _ -> :does_not_matter end)

      actual = conn |> get(url) |> response(200)

      assert "id,int_array\n1,\"2,3,4\"\n" == actual
    end

    test "does not return bbox calculation when feature list is empty", %{conn: conn} do
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

      org_name = @org_name
      model_name = model.name
      stub(@system_name_cache, :get, fn ^org_name, ^model_name -> dataset_id end)
      stub(@model, :get, fn ^dataset_id -> model end)

      stub(@presto_service, :preview_columns, fn _ ->
        ["feature"]
      end)

      stub(@prestige, :stream!, fn _, _ -> Stream.map([], &{:ok, &1}) end)

      stub(@redix, :command!, fn _, _ -> :does_not_matter end)

      actual = conn |> put_req_header("accept", "application/geo+json") |> get(url) |> response(200)

      expected = %{
        "type" => "FeatureCollection",
        "name" => "#{@org_name}__stan",
        "features" => []
      }

      assert expected == actual |> Jason.decode!()
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

      org_name = @org_name
      model_name = model.name
      stub(@system_name_cache, :get, fn ^org_name, ^model_name -> dataset_id end)
      stub(@model, :get, fn ^dataset_id -> model end)

      stub(@presto_service, :preview_columns, fn _ ->
        ["feature"]
      end)

      stub(@prestige, :stream!, fn _, _ ->
        Stream.map([%{"feature" => "{\"geometry\":{\"coordinates\":[0,1]}}"}], &{:ok, &1})
      end)

      stub(@redix, :command!, fn _, _ -> :does_not_matter end)

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

    test "returns columns in correct order even if dictionary is out of order", %{conn: conn} do
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
            %{name: "bob", type: "integer"},
            %{name: "andi", type: "integer"}
          ]
        })

      org_name = @org_name
      model_name = model.name
      stub(@system_name_cache, :get, fn ^org_name, ^model_name -> dataset_id end)
      stub(@model, :get, fn ^dataset_id -> model end)

      stub(@presto_service, :preview_columns, fn _ ->
        ["bob", "andi"]
      end)

      stub(@prestige, :stream!, fn _, _ -> Stream.map([%{"andi" => 1, "bob" => 2}], &{:ok, &1}) end)

      stub(@redix, :command!, fn _, _ -> :does_not_matter end)

      actual = conn |> get(url) |> response(200)

      assert "andi,bob\n1,2\n" == actual
    end
  end

  describe "metrics" do
    setup do
      stub(@prestige, :stream!, fn _, _ ->
        Stream.map([%{"id" => 1, "name" => "Joe"}, %{"id" => 2, "name" => "Robby"}], &{:ok, &1})
      end)

      :ok
    end

    @tag timeout: 1000
    data_test "increments dataset download count when user requests download", %{conn: conn} do
      # Expect call to MetricsService.record_api_hit for dataset downloads
      expect(@metrics_service, :record_api_hit, fn "downloads", _dataset_id -> :ok end)

      conn
      |> get(url)
      |> response(200)
      
      # Give the Task time to complete
      Process.sleep(100)

      where(
        url: [
          "/api/v1/dataset/1234-4567-89101/download?_format=csv",
          "/api/v1/organization/org1/dataset/data1/download?_format=csv",
          "/api/v1/dataset/1234-4567-89101/download?_format=json",
          "/api/v1/organization/org1/dataset/data1/download?_format=json"
        ]
      )
    end

    @tag timeout: 1000
    data_test "does not increment dataset download count when ui requests download", %{conn: conn} do
      # Expect no calls to MetricsService for these UI requests (origin header present)
      expect(@metrics_service, :record_api_hit, 0, fn _, _ -> :ok end)

      conn
      |> Plug.Conn.put_req_header("origin", "data.integration.tests.example.com")
      |> get(url)
      |> response(200)
      
      # Give time for any potential Task to complete
      Process.sleep(100)

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

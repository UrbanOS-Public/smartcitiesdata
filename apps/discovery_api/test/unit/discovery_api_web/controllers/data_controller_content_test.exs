defmodule DiscoveryApiWeb.DataController.ContentTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  import Checkov
  alias DiscoveryApi.Data.{Model, SystemNameCache}
  alias DiscoveryApi.Services.{PrestoService, MetricsService}
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils

  setup :verify_on_exit!
  setup :set_mox_from_context

  @dataset_id "1234-4567-89101"
  @system_name "foobar__company_data"
  @org_name "org1"
  @data_name "data1"
  @geo_json_features_raw [
    %{"geometry" => %{"coordinates" => [[0, 0], [0, 1]]}},
    %{"geometry" => %{"coordinates" => [[1, 0]]}},
    %{"geometry" => %{"coordinates" => [[1, 1]]}},
    %{"geometry" => %{"coordinates" => [[0, 1]]}}
  ]
  @geo_json_features_encoded Enum.map(@geo_json_features_raw, &Jason.encode!/1)
  @geo_json_features Enum.map(@geo_json_features_encoded, fn x -> %{"feature" => x} end)

  describe "geojson data" do
    defp assert_content_matches(:csv, actual) do
      assert "feature\n\"{\"\"geometry\"\":{\"\"coordinates\"\":[[0,0],[0,1]]}}\"\n\"{\"\"geometry\"\":{\"\"coordinates\"\":[[1,0]]}}\"\n\"{\"\"geometry\"\":{\"\"coordinates\"\":[[1,1]]}}\"\n\"{\"\"geometry\"\":{\"\"coordinates\"\":[[0,1]]}}\"\n" ==
               actual
    end

    defp assert_content_matches(:json, actual) do
      assert @geo_json_features == Jason.decode!(actual)
    end

    defp assert_content_matches(:preview_json, actual) do
      assert %{"meta" => %{"columns" => ["feature"]}, "data" => @geo_json_features} == Jason.decode!(actual)
    end

    defp assert_content_matches(:geojson, actual) do
      assert %{
               "bbox" => [0, 0, 1, 1],
               "features" => @geo_json_features_raw,
               "name" => "foobar__company_data",
               "type" => "FeatureCollection"
             } == Jason.decode!(actual)
    end

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
          schema: [
            %{name: "number", type: "integer"},
            %{name: "name", type: "string"}
          ]
        })

      stub(SystemNameCacheMock, :get, fn _org_name, _data_name -> @dataset_id end)
      stub(ModelMock, :get, fn _dataset_id -> model end)
      stub(QueryAccessUtilsMock, :get_affected_models, fn _arg -> {:ok, nil} end)
      stub(QueryAccessUtilsMock, :user_is_authorized?, fn _arg1, _arg2, _arg3 -> true end)
      
      # MetricsService uses :meck like in previous files for passthrough behavior
      :meck.expect(MetricsService, :record_api_hit, fn _arg1, _arg2 -> :does_not_matter end)

      # these clearly need to be condensed
      stub(PrestoServiceMock, :get_column_names, fn _arg1, _arg2, _arg3 -> {:ok, ["feature"]} end)
      stub(PrestoServiceMock, :preview_columns, fn _arg -> ["feature"] end)
      stub(PrestoServiceMock, :preview, fn _arg1, @system_name, _arg3 -> @geo_json_features end)
      stub(PrestoServiceMock, :build_query, fn _arg1, _arg2, _arg3, _arg4 -> {:ok, "select * from #{@system_name}"} end)

      stub(PrestigeMock, :new_session, fn _arg -> :connect end)
      stub(PrestigeMock, :query!, fn _arg, "select * from #{@system_name}" -> :result end)
      stub(PrestigeMock, :stream!, fn _arg1, _arg2 -> [:result] end)

      # Prestige.Result.as_maps needs special handling - use PrestigeResultMock
      stub(PrestigeResultMock, :as_maps, fn _arg ->
        [
          %{"feature" => "{\"geometry\":{\"coordinates\":[[0,0],[0,1]]}}"},
          %{"feature" => "{\"geometry\":{\"coordinates\":[[1,0]]}}"},
          %{"feature" => "{\"geometry\":{\"coordinates\":[[1,1]]}}"},
          %{"feature" => "{\"geometry\":{\"coordinates\":[[0,1]]}}"}
        ]
      end)

      :ok
    end

    data_test "returns data in #{expected_format} format for url #{url} and headers #{inspect(headers)}", %{conn: conn} do
      conn =
        Enum.reduce(headers, conn, fn header, conn ->
          {header_key, header_value} = header
          put_req_header(conn, header_key, header_value)
        end)

      actual_content = conn |> get(url) |> response(200)
      assert_content_matches(expected_format, actual_content)

      where([
        [:url, :headers, :expected_format],
        ["/api/v1/dataset/1234-4567-89101/download", [], :csv],
        ["/api/v1/dataset/1234-4567-89101/download", [{"accept", "text/csv"}], :csv],
        ["/api/v1/organization/org1/dataset/data1/download", [{"accept", "text/csv"}], :csv],
        ["/api/v1/dataset/1234-4567-89101/download?_format=csv", [], :csv],
        ["/api/v1/organization/org1/dataset/data1/download?_format=csv", [], :csv],
        ["/api/v1/dataset/1234-4567-89101/download", [{"accept", "application/json"}], :json],
        ["/api/v1/organization/org1/dataset/data1/download", [{"accept", "application/json"}], :json],
        ["/api/v1/dataset/1234-4567-89101/download?_format=json", [], :json],
        ["/api/v1/organization/org1/dataset/data1/download?_format=json", [], :json],
        ["/api/v1/dataset/1234-4567-89101/query", [], :csv],
        ["/api/v1/dataset/1234-4567-89101/query", [{"accept", "text/csv"}], :csv],
        ["/api/v1/organization/org1/dataset/data1/download", [{"accept", "text/csv"}], :csv],
        ["/api/v1/dataset/1234-4567-89101/query?format=csv", [], :csv],
        ["/api/v1/organization/org1/dataset/data1/query?_format=csv", [], :csv],
        ["/api/v1/dataset/1234-4567-89101/query", [{"accept", "application/json"}], :json],
        ["/api/v1/organization/org1/dataset/data1/query", [{"accept", "application/json"}], :json],
        ["/api/v1/dataset/1234-4567-89101/query?_format=json", [], :json],
        ["/api/v1/organization/org1/dataset/data1/query?_format=json", [], :json],
        ["/api/v1/dataset/1234-4567-89101/preview", [], :preview_json],
        ["/api/v1/dataset/1234-4567-89101/preview", [{"accept", "text/csv"}], :csv],
        ["/api/v1/organization/org1/dataset/data1/preview", [{"accept", "text/csv"}], :csv],
        ["/api/v1/dataset/1234-4567-89101/preview?_format=csv", [], :csv],
        ["/api/v1/organization/org1/dataset/data1/preview?_format=csv", [], :csv],
        ["/api/v1/dataset/1234-4567-89101/preview", [{"accept", "application/json"}], :preview_json],
        ["/api/v1/organization/org1/dataset/data1/preview", [{"accept", "application/json"}], :preview_json],
        ["/api/v1/dataset/1234-4567-89101/preview?_format=json", [], :preview_json],
        ["/api/v1/organization/org1/dataset/data1/preview?_format=json", [], :preview_json],
        ["/api/v1/dataset/1234-4567-89101/download", [{"accept", "application/geo+json"}], :geojson],
        ["/api/v1/organization/org1/dataset/data1/download", [{"accept", "application/geo+json"}], :geojson],
        ["/api/v1/dataset/1234-4567-89101/download?_format=geojson", [], :geojson],
        ["/api/v1/organization/org1/dataset/data1/download?_format=geojson", [], :geojson],
        ["/api/v1/dataset/1234-4567-89101/query", [{"accept", "application/geo+json"}], :geojson],
        ["/api/v1/organization/org1/dataset/data1/query", [{"accept", "application/geo+json"}], :geojson],
        ["/api/v1/dataset/1234-4567-89101/query?_format=geojson", [], :geojson],
        ["/api/v1/organization/org1/dataset/data1/query?_format=geojson", [], :geojson],
        ["/api/v1/dataset/1234-4567-89101/preview", [{"accept", "application/geo+json"}], :geojson],
        ["/api/v1/organization/org1/dataset/data1/preview", [{"accept", "application/geo+json"}], :geojson],
        ["/api/v1/dataset/1234-4567-89101/preview?_format=geojson", [], :geojson],
        ["/api/v1/organization/org1/dataset/data1/preview?_format=geojson", [], :geojson]
      ])
    end
  end
end

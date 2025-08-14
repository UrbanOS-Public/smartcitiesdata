defmodule DiscoveryApiWeb.DataController.ContentTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  import Checkov

  @moduletag timeout: 5000

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

      # SystemNameCache mock needs to handle the specific org/data name pairs
      stub(SystemNameCacheMock, :get, fn org_name, data_name ->
        case {org_name, data_name} do
          {"org1", "data1"} -> @dataset_id
          _ -> @dataset_id  # fallback for any other combination
        end
      end)
      
      # ModelMock needs to handle both direct dataset_id calls and result from SystemNameCache
      stub(ModelMock, :get, fn dataset_id ->
        case dataset_id do
          @dataset_id -> model
          _ -> nil  # Return nil for unknown dataset_ids
        end
      end)
      
      # ModelMock.get_all/0 is called by QueryAccessUtils.map_affected_tables_to_models/1
      stub(ModelMock, :get_all, fn -> [model] end)
      
      stub(QueryAccessUtilsMock, :get_affected_models, fn _arg -> {:ok, [model]} end)
      stub(QueryAccessUtilsMock, :user_is_authorized?, fn _arg1, _arg2, _arg3 -> true end)
      
      # ModelAccessUtilsMock is called by QueryAccessUtils.user_can_access_models?/2
      stub(ModelAccessUtilsMock, :has_access?, fn _model, _user -> true end)
      
      # MetricsService uses Mox since it has dependency injection
      stub(MetricsServiceMock, :record_api_hit, fn _label, _id -> :ok end)

      # PrestoService mocks - these need to be comprehensive for both controllers
      stub(PrestoServiceMock, :get_column_names, fn _arg1, _arg2, _arg3 -> {:ok, ["feature"]} end)
      stub(PrestoServiceMock, :preview_columns, fn _arg -> ["feature"] end)
      stub(PrestoServiceMock, :preview, fn _session, system_name, _schema ->
        case system_name do
          @system_name -> @geo_json_features
          _ -> []
        end
      end)
      stub(PrestoServiceMock, :build_query, fn _arg1, _arg2, _arg3, _arg4 -> {:ok, "select * from #{@system_name}"} end)
      stub(PrestoServiceMock, :is_select_statement?, fn _query -> true end)
      stub(PrestoServiceMock, :get_affected_tables, fn _session, _query -> {:ok, [@system_name]} end)
      
      # Additional PrestoService mocks needed for DataDownloadController
      stub(PrestoServiceMock, :format_select_statement_from_schema, fn _schema -> "*" end)
      stub(PrestoServiceMock, :map_prestige_results_to_schema, fn data, _schema -> data end)

      # Prestige mocks - these need to prevent real HTTP connections
      stub(PrestigeMock, :new_session, fn _opts -> :connection end)
      stub(PrestigeMock, :query!, fn _connection, _query -> :result end)
      stub(PrestigeMock, :stream!, fn _connection, _query -> [:result] end)

      # PrestigeResult mock for converting query results - handles both DataController and DataDownloadController
      stub(PrestigeResultMock, :as_maps, fn result ->
        case result do
          :result ->
            [
              %{"feature" => "{\"geometry\":{\"coordinates\":[[0,0],[0,1]]}}"},
              %{"feature" => "{\"geometry\":{\"coordinates\":[[1,0]]}}"},
              %{"feature" => "{\"geometry\":{\"coordinates\":[[1,1]]}}"},
              %{"feature" => "{\"geometry\":{\"coordinates\":[[0,1]]}}"}
            ]
          _ ->
            [
              %{"feature" => "{\"geometry\":{\"coordinates\":[[0,0],[0,1]]}}"},
              %{"feature" => "{\"geometry\":{\"coordinates\":[[1,0]]}}"},
              %{"feature" => "{\"geometry\":{\"coordinates\":[[1,1]]}}"},
              %{"feature" => "{\"geometry\":{\"coordinates\":[[0,1]]}}"}
            ]
        end
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

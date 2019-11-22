defmodule DiscoveryApiWeb.DataController.ContentTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  import Checkov
  alias DiscoveryApi.Data.{Model, SystemNameCache}
  alias DiscoveryApi.Services.{PrestoService, MetricsService}
  alias DiscoveryApiWeb.Utilities.AuthUtils

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

      allow(SystemNameCache.get(@org_name, @data_name), return: @dataset_id)
      allow(Model.get(@dataset_id), return: model)
      allow(AuthUtils.authorized_to_query?(any(), any()), return: true, meck_options: [:passthrough])
      allow(MetricsService.record_api_hit(any(), any()), return: :does_not_matter)

      # these clearly need to be condensed
      allow(PrestoService.get_column_names(any(), any(), any()), return: {:ok, ["feature"]})
      allow(PrestoService.preview_columns(any(), @system_name), return: ["feature"])
      allow(PrestoService.preview(any(), @system_name), return: @geo_json_features)
      allow(PrestoService.build_query(any(), any()), return: {:ok, "select * from #{@system_name}"})

      allow(Prestige.new_session(any()), return: :connect)
      allow(Prestige.query!(any(), "select * from #{@system_name}"), return: :result)

      allow(Prestige.Result.as_maps(:result),
        return: [
          %{"feature" => "{\"geometry\":{\"coordinates\":[[0,0],[0,1]]}}"},
          %{"feature" => "{\"geometry\":{\"coordinates\":[[1,0]]}}"},
          %{"feature" => "{\"geometry\":{\"coordinates\":[[1,1]]}}"},
          %{"feature" => "{\"geometry\":{\"coordinates\":[[0,1]]}}"}
        ]
      )

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

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

  setup do
    model =
      Helper.sample_model(%{
        id: @dataset_id,
        systemName: @system_name,
        name: @data_name,
        private: false,
        lastUpdatedDate: nil,
        queries: 7,
        downloads: 9
      })

    allow(SystemNameCache.get(@org_name, @data_name), return: @dataset_id)
    allow(Model.get(@dataset_id), return: model)
    allow(AuthUtils.authorized_to_query?(any(), any()), return: true, meck_options: [:passthrough])
    allow(MetricsService.record_api_hit(any(), any()), return: :does_not_matter)

    # these clearly need to be condensed
    allow(PrestoService.get_column_names(any(), any()), return: {:ok, ["id", "name", "age"]})
    allow(PrestoService.preview_columns(@system_name), return: ["id", "name", "age"])
    allow(PrestoService.preview(@system_name), return: [[1, "Joe", 21], [2, "Robby", 32]])
    allow(PrestoService.build_query(any(), any()), return: {:ok, "select * from #{@system_name}"})
    allow(Prestige.execute("select * from #{@system_name}"), return: [[1, "Joe", 21], [2, "Robby", 32]])

    :ok
  end

  defp assert_content_matches(:csv, actual) do
    assert "id,name,age\n1,Joe,21\n2,Robby,32\n" == actual
  end

  defp assert_content_matches(:json, actual) do
    assert [%{"id" => 1, "name" => "Joe", "age" => 21}, %{"id" => 2, "name" => "Robby", "age" => 32}] == Jason.decode!(actual)
  end

  defp assert_content_matches(:preview_json, actual) do
    assert %{"meta" => %{"columns" => ["id", "name", "age"]}, "data" => [[1, "Joe", 21], [2, "Robby", 32]]} == Jason.decode!(actual)
  end

  describe "content negotiation" do
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
        ["/api/v1/organization/org1/dataset/data1/preview?_format=json", [], :preview_json]
      ])
    end
  end
end

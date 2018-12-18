defmodule DiscoveryApiWeb.DatasetCSVControllerTest do
  use ExUnit.Case
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoverApi.Data.Thrive
  alias StreamingMetrics.PrometheusMetricCollector, as: MetricCollector

  describe "fetch dataset csv" do
    setup do
      mock_hive_schema_result = %{
        "fields" => [
          %{
            "name" => "name"
          },
          %{
            "name" => "animal"
          },
          %{
            "name" => "age"
          }
        ]
      }

      allow(HTTPoison.get(ends_with("feed/1"), any()),
        return: HttpHelper.create_response(body: generate_metadata_result)
      )

      allow(HTTPoison.get(ends_with("schemas/test/tables/bigdata"), any()),
        return: HttpHelper.create_response(body: mock_hive_schema_result)
      )

      allow(
        Thrive.stream_results(
          any(),
          any()
        ),
        return: {:ok, Stream.take(get_common_expected_data(), 3)}
      )

      :ok
    end

    test "maps the data to the correct structure", %{conn: conn} do
      actual = get(conn, "/v1/api/dataset/1/csv") |> response(200)
      assert(generate_expected_csv() == actual)
    end

    test "metrics are sent for a count of the uncached entities" do
      expect(
        MetricCollector.record_metrics(
          [
            %{
              name: "downloaded_csvs",
              value: 1,
              dimensions: [{"PodHostname", any()}, {"DatasetId", "1"}]
            }
          ],
          "discovery_api"
        ),
        return: {:ok, %{}},
        meck_options: [:passthrough]
      )

      get(conn, "/v1/api/dataset/1/csv")
    end
  end

  describe "error paths" do
    test "kylo feed down returns 500" do
      allow(HTTPoison.get(ends_with("feed/1"), any()),
        return: HttpHelper.create_response(error_reason: "There was an error")
      )

      assert get(conn, "/v1/api/dataset/1/csv")
             |> response(500)
    end

    test "kylo hive metadata down returns 500" do
      allow(HTTPoison.get(ends_with("feed/1"), any()),
        return: HttpHelper.create_response(body: generate_metadata_result)
      )

      allow(HTTPoison.get(ends_with("schemas/test/tables/bigdata"), any()),
        return: HttpHelper.create_response(error_reason: "There was an error")
      )

      assert get(conn, "/v1/api/dataset/1/csv")
             |> response(500)
    end

    test "thrive streaming down returns 500" do
      mock_hive_schema_result = %{
        "fields" => [
          %{
            "name" => "name"
          }
        ]
      }

      allow(
        HTTPoison.get(ends_with("feed/1"), any()),
        return: HttpHelper.create_response(body: generate_metadata_result)
      )

      allow(
        HTTPoison.get(ends_with("schemas/test/tables/bigdata"), any()),
        return: HttpHelper.create_response(body: mock_hive_schema_result)
      )

      allow(
        Thrive.stream_results(any(), any()),
        return: {:error, "everything is awesome"}
      )

      assert get(conn, "/v1/api/dataset/1/csv")
             |> response(500)
    end
  end

  defp get_common_expected_data() do
    [
      {"Austin5", "The Worst5", 25},
      {"Austin6", "The Worst6", 26}
    ]
  end

  defp generate_metadata_result() do
    %{
      "systemName" => "bigdata",
      "category" => %{
        "systemName" => "test"
      }
    }
  end

  defp generate_expected_csv() do
    """
    name,animal,age
    Austin5,The Worst5,25
    Austin6,The Worst6,26
    """
  end
end

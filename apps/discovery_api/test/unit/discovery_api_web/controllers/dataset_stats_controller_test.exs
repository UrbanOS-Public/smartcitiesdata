defmodule DiscoveryApiWeb.DatasetStatsControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Data.Persistence
  alias DiscoveryApi.Data.Model

  @dataset_id "123"

  describe "fetch dataset stats" do
    test "retrieves stats for dataset when stats exist", %{conn: conn} do
      model = Helper.sample_model(%{id: @dataset_id})
      allow(Model.get(@dataset_id), return: model)

      allow(Persistence.get("discovery-api:stats:#{@dataset_id}"),
        return: mock_stats(),
        meck_options: [:passthrough]
      )

      actual = conn |> get("api/v1/dataset/#{@dataset_id}/stats") |> json_response(200)

      assert %{
               "completeness" => 0.8333333333333334,
               "fields" => %{"age" => %{"count" => 2, "required" => false}, "name" => %{"count" => 3, "required" => false}},
               "id" => 123,
               "record_count" => 3
             } == actual
    end

    test "Returns an empty response when the stats do not exist", %{conn: conn} do
      model = Helper.sample_model(%{id: @dataset_id})
      allow(Model.get(@dataset_id), return: model)

      allow(Persistence.get("discovery-api:stats:#{@dataset_id}"),
        return: nil,
        meck_options: [:passthrough]
      )

      actual = conn |> get("api/v1/dataset/#{@dataset_id}/stats") |> json_response(200)

      assert %{} == actual
    end
  end

  def mock_stats do
    %{
      "completeness" => 0.8333333333333334,
      "fields" => %{
        "age" => %{"count" => 2, "required" => false},
        "name" => %{"count" => 3, "required" => false}
      },
      "id" => 123,
      "record_count" => 3
    }
    |> Jason.encode!()
  end
end

defmodule DiscoveryApiWeb.DataController.StatsTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  alias DiscoveryApi.Test.Helper

  @moduletag timeout: 5000

  setup :verify_on_exit!
  setup :set_mox_from_context

  @dataset_id "123"

  describe "fetch dataset stats" do
    test "retrieves stats for dataset when stats exist", %{conn: conn} do
      model = Helper.sample_model(%{id: @dataset_id})
      stub(ModelMock, :get, fn dataset_id ->
        case dataset_id do
          @dataset_id -> model
          _ -> nil
        end
      end)

      stub(RedixMock, :command!, fn :redix, command ->
        case command do
          ["GET", "discovery-api:stats:#{@dataset_id}"] -> mock_stats()
          _ -> nil
        end
      end)

      actual = conn |> get("/api/v1/dataset/#{@dataset_id}/stats") |> json_response(200)

      assert %{
               "completeness" => 0.8333333333333334,
               "fields" => %{"age" => %{"count" => 2, "required" => false}, "name" => %{"count" => 3, "required" => false}},
               "id" => 123,
               "record_count" => 3
             } == actual
    end

    test "Returns an empty response when the stats do not exist", %{conn: conn} do
      model = Helper.sample_model(%{id: @dataset_id})
      stub(ModelMock, :get, fn dataset_id ->
        case dataset_id do
          @dataset_id -> model
          _ -> nil
        end
      end)

      stub(RedixMock, :command!, fn :redix, command ->
        case command do
          ["GET", "discovery-api:stats:#{@dataset_id}"] -> nil
          _ -> nil
        end
      end)

      actual = conn |> get("/api/v1/dataset/#{@dataset_id}/stats") |> json_response(200)

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

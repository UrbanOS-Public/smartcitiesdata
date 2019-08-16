defmodule DiscoveryApiWeb.DataController.MetricsTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Data.Model

  describe "fetching dataset metrics" do
    setup do
      allow(Model.get_count_maps("123"), return: %{"queries" => "7", "downloads" => "9"})
      allow(Model.get_count_maps("456"), return: %{})
      :ok
    end

    test "retrives metrics for valid dataset", %{conn: conn} do
      model = DiscoveryApi.Test.Helper.sample_model(%{id: "123"})
      allow(DiscoveryApi.Data.Model.get(model.id), return: model)

      expected = %{"downloads" => "9", "queries" => "7"}
      actual = conn |> get("/api/v1/dataset/123/metrics") |> json_response(200)
      assert actual == expected
    end

    test "returns empty map when no metrics exist for dataset", %{conn: conn} do
      model = DiscoveryApi.Test.Helper.sample_model(%{id: "456"})
      allow(DiscoveryApi.Data.Model.get(model.id), return: model)

      expected = %{}
      actual = conn |> get("/api/v1/dataset/456/metrics") |> json_response(200)
      assert actual == expected
    end
  end
end

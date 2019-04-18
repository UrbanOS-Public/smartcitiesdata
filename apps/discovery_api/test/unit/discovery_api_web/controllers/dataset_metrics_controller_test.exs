defmodule DiscoveryApiWeb.DatasetMetricsControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Data.Persistence

  describe "fetching dataset metrics" do
    setup do
      keys = ["smart_registry:queries:count:123", "smart_registry:downloads:count:123"]
      allow(Persistence.get_keys("smart_registry:*:count:123"), return: keys)
      allow(Persistence.get_keys("smart_registry:*:count:456"), return: nil)
      allow(Persistence.get_many(keys), return: ["7", "9"])
      :ok
    end

    test "retrives metrics for valid dataset", %{conn: conn} do
      expected = %{"downloads" => "9", "queries" => "7"}
      actual = conn |> get("/api/v1/dataset/123/metrics") |> json_response(200)
      assert actual == expected
    end

    test "returns empty map when no metrics exist for dataset", %{conn: conn} do
      expected = %{}
      actual = conn |> get("/api/v1/dataset/456/metrics") |> json_response(200)
      assert actual == expected
    end
  end
end

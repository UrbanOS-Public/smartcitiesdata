defmodule DiscoveryApiWeb.DataController.MetricsTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  alias DiscoveryApi.Data.Model

  setup :verify_on_exit!

  describe "fetching dataset metrics" do
    setup do
      stub(ModelMock, :get_count_maps, fn
        "123" -> %{"queries" => "7", "downloads" => "9"}
        "456" -> %{}
      end)
      :ok
    end

    test "retrives metrics for valid dataset", %{conn: conn} do
      model = DiscoveryApi.Test.Helper.sample_model(%{id: "123"})
      stub(ModelMock, :get, fn "123" -> model end)

      expected = %{"downloads" => "9", "queries" => "7"}
      actual = conn |> get("/api/v1/dataset/123/metrics") |> json_response(200)
      assert actual == expected
    end

    test "returns empty map when no metrics exist for dataset", %{conn: conn} do
      model = DiscoveryApi.Test.Helper.sample_model(%{id: "456"})
      stub(ModelMock, :get, fn "456" -> model end)

      expected = %{}
      actual = conn |> get("/api/v1/dataset/456/metrics") |> json_response(200)
      assert actual == expected
    end
  end
end

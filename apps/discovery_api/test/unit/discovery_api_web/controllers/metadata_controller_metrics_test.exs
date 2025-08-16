defmodule DiscoveryApiWeb.DataController.MetricsTest do
  use DiscoveryApiWeb.ConnCase
  import Mox

  @moduletag timeout: 5000

  setup :verify_on_exit!
  setup :set_mox_from_context

  describe "fetching dataset metrics" do
    setup do
      # Set up PersistenceMock expectations for Model.get_count_maps behavior
      stub(PersistenceMock, :get_keys, fn
        "smart_registry:*:count:123" -> ["smart_registry:queries:count:123", "smart_registry:downloads:count:123"]
        "smart_registry:*:count:456" -> []
      end)
      
      stub(PersistenceMock, :get_many, fn
        ["smart_registry:queries:count:123", "smart_registry:downloads:count:123"] -> ["7", "9"]
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

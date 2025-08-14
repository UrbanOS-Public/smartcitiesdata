defmodule DiscoveryApiWeb.Plugs.GetModelTest do
  use DiscoveryApiWeb.ConnCase
  import Mox

  alias DiscoveryApi.Data.SystemNameCache
  alias DiscoveryApiWeb.Plugs.GetModel

  alias SmartCity.TestDataGenerator, as: TDG

  setup :verify_on_exit!
  setup :set_mox_from_context

  describe "call/2" do
    setup do
      Cachex.clear(SystemNameCache.cache_name())
      
      # Use :meck for DiscoveryApiWeb.RenderError since it doesn't have dependency injection
      try do
        :meck.new(DiscoveryApiWeb.RenderError, [:non_strict])
      catch
        _, _ -> :ok
      end
      
      on_exit(fn ->
        try do
          :meck.unload(DiscoveryApiWeb.RenderError)
        catch
          _, _ -> :ok
        end
      end)
      
      :ok
    end

    test "replaces the org_name and dataset_name with the correct dataset_id" do
      org = DiscoveryApi.Test.Helper.create_schema_organization(orgName: "org1")
      dataset1 = TDG.create_dataset(id: "ds1", technical: %{orgId: org.id, dataName: "data1"})

      SystemNameCache.put(dataset1.id, org.name, dataset1.technical.dataName)
      # Use ModelMock since GetModel plug uses dependency injection
      stub(ModelMock, :get, fn id -> 
        assert id == dataset1.id
        :model
      end)

      conn = build_conn(:get, "/doesnt/matter", %{"org_name" => "org1", "dataset_name" => "data1"})
      %{assigns: assigns} = GetModel.call(conn, [])

      assert :model == assigns.model
    end

    test "responds with a 404 when org_name and dataset_name combination is not known" do
      # Use :meck for RenderError since it doesn't have dependency injection
      :meck.expect(DiscoveryApiWeb.RenderError, :render_error, fn conn, status, message -> 
        assert status == 404
        assert message == "Not Found"
        conn
      end)
      
      conn = build_conn(:get, "/doesnt/matter", %{"org_name" => "org1", "dataset_name" => "data1"})
      result = GetModel.call(conn, [])

      # Verify the function was called with :meck
      assert :meck.called(DiscoveryApiWeb.RenderError, :render_error, [conn, 404, "Not Found"])
      assert result.halted == true
    end
  end
end

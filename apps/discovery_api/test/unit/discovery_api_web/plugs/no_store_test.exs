defmodule DiscoveryApiWeb.Plugs.NoStoreTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  alias DiscoveryApiWeb.Plugs.NoStore

  setup :verify_on_exit!
  setup :set_mox_from_context

  describe "call/2" do
    test "adds cache-control: no-store to connection header" do
      conn = build_conn(:get, "/doesnt/matter")
      conn = NoStore.call(conn, [])
      assert ["no-cache, no-store, must-revalidate"] == get_resp_header(conn, "cache-control")
      assert ["no-cache"] == get_resp_header(conn, "pragma")
    end
  end

  describe "router global_headers pipeline" do
    setup do
      # Use :meck for modules without dependency injection (Prestige, Prestige.Result)
      try do
        :meck.new(Prestige, [:non_strict])
        :meck.new(Prestige.Result, [:non_strict])
      catch
        _, _ -> :ok
      end
      
      on_exit(fn ->
        try do
          :meck.unload(Prestige)
          :meck.unload(Prestige.Result)
        catch
          _, _ -> :ok
        end
      end)
      
      :ok
    end

    test "response has the no-store header set", %{conn: conn} do
      dataset_id = "pedro"
      org_name = "an_org"
      url = "/api/v1/dataset/#{dataset_id}/download"

      model =
        Helper.sample_model(%{
          id: dataset_id,
          systemName: "#{org_name}__paco",
          name: "paco",
          organizationDetails: %{
            orgName: org_name
          },
          schema: [
            %{name: "bob", type: "integer"},
            %{name: "andi", type: "integer"}
          ]
        })

      # Use Mox for services with dependency injection
      stub(SystemNameCacheMock, :get, fn _, _ -> dataset_id end)
      stub(ModelMock, :get, fn ^dataset_id -> model end)
      stub(PrestoServiceMock, :preview_columns, fn _ -> ["bob", "andi"] end)
      stub(RedixMock, :command!, fn _, _ -> :does_not_matter end)
      # Add MetricsServiceMock expectation for RecordMetrics plug
      stub(MetricsServiceMock, :record_api_hit, fn _, _ -> :ok end)

      # Use :meck for modules without dependency injection
      :meck.expect(Prestige, :new_session, fn _ -> :connection end)
      :meck.expect(Prestige, :stream!, fn _, _ -> [:result] end)
      :meck.expect(Prestige.Result, :as_maps, fn _ -> [%{"andi" => 1, "bob" => 2}] end)

      conn = get(conn, url)
      assert ["no-cache, no-store, must-revalidate"] == get_resp_header(conn, "cache-control")
      assert ["no-cache"] == get_resp_header(conn, "pragma")
    end
  end
end

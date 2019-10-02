defmodule DiscoveryApiWeb.Plugs.NoStoreTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApiWeb.Plugs.NoStore
  alias DiscoveryApi.Data.{Model, SystemNameCache}
  alias DiscoveryApi.Services.PrestoService

  describe "call/2" do
    test "adds cache-control: no-store to connection header" do
      conn = build_conn(:get, "/doesnt/matter")
      conn = NoStore.call(conn, [])
      assert ["no-store"] == get_resp_header(conn, "cache-control")
      assert ["no-cache"] == get_resp_header(conn, "pragma")
    end
  end

  describe "router global_headers pipeline" do
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

      allow(SystemNameCache.get(any(), any()), return: dataset_id)
      allow(Model.get(dataset_id), return: model)

      allow(PrestoService.preview_columns(any()),
        return: ["bob", "andi"]
      )

      allow(Prestige.execute(any(), any()),
        return: [%{"andi" => 1, "bob" => 2}]
      )

      allow(Prestige.prefetch(any()),
        return: [%{"andi" => 1, "bob" => 2}]
      )

      allow(Redix.command!(any(), any()), return: :does_not_matter)

      conn = get(conn, url)
      assert ["no-store"] == get_resp_header(conn, "cache-control")
      assert ["no-cache"] == get_resp_header(conn, "pragma")
    end
  end
end

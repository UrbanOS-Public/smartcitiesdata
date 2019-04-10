defmodule DiscoveryApiWeb.Plugs.OrgDatasetParamReplacementTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  import Checkov

  alias DiscoveryApi.Data.SystemNameCache
  alias DiscoveryApiWeb.Plugs.OrgDatasetParamReplacement

  alias SmartCity.TestDataGenerator, as: TDG

  describe "call/2" do

    setup do
      Cachex.clear(SystemNameCache.cache_name())
      :ok
    end

    test "replaces the org_name and dataset_name with the correct dataset_id" do
      dataset = TDG.create_dataset(id: "ds1", technical: %{orgName: "org1", dataName: "data1"})
      SystemNameCache.put(dataset)
      SystemNameCache.put(TDG.create_dataset(id: "ds2"))

      conn = build_conn(:get, "/doesnt/matter", %{"org_name" => "org1", "dataset_name" => "data1"})
      %{params: params} = OrgDatasetParamReplacement.call(conn, [])

      assert %{"dataset_id" => "ds1"} == params
    end

    test "responds with a 404 when org_name and dataset_name combination is not known" do
      allow DiscoveryApiWeb.RenderError.render_error(any(), any(), any()), exec: fn conn, _, _ -> conn end
      conn = build_conn(:get, "/doesnt/matter", %{"org_name" => "org1", "dataset_name" => "data1"})
      result = OrgDatasetParamReplacement.call(conn, [])

      assert_called DiscoveryApiWeb.RenderError.render_error(conn, 404, "Not Found")
      assert result.halted == true
    end

    data_test "passes conn through when params are #{inspect(params)}" do
      conn = build_conn(:get, "/doesnt/matter", params)
      assert conn == OrgDatasetParamReplacement.call(conn, [])

      where(
        params: [
          %{"dataset_id" => "ds1"},
          %{"org_name" => "org1", "dataset_id" => "ds1"},
          %{"dataset_name" => "data1"}
        ]
      )
    end
  end
end

defmodule Raptor.Services.DatasetStoreTest do
    use RaptorWeb.ConnCase
    use Placebo
    alias Raptor.Services.DatasetStore
    alias Raptor.Schemas.Dataset
  
    @namespace "raptor:datasets:"
    @redix Raptor.Application.redis_client()
  
    test "get all with no datasets returns empty list", %{conn: conn} do
      allow(Redix.command!(@redix, ["KEYS", @namespace <> "*"]), return: [])
  
      actualDatasets = DatasetStore.get_all()
  
      assert [] == actualDatasets
    end
  
    test "get all with datasets returns list of Raptor datasets", %{conn: conn} do
      keys = ["raptor:datasets:system__name", "raptor:datasets:system__name_2"]
      allow(Redix.command!(@redix, ["KEYS", @namespace <> "*"]), return: keys)
      allow(Redix.command!(@redix, ["MGET" | keys]), return: ["{\"dataset_id\":\"1\",\"org_id\":\"system\",\"system_name\":\"system__name\"}",
      "{\"dataset_id\":\"2\",\"org_id\":\"ba824aca-be38-4ca7-889a-1224c24ccc47\",\"system_name\":\"Nero_Coco__Greige_Blue_ORCXK\"}"])
  
      expectedDatasets = [%Dataset{dataset_id: "", system_name: "system__name", org_id: "", dataset_id: "", system_name: "system__name_2", org_id: ""}]
  
      actualDatasets = DatasetStore.get_all()
  
      assert expectedDatasets == actualDatasets
    end
  end
  
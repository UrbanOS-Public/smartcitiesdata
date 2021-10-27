defmodule Raptor.Services.DatasetStoreTest do
  use RaptorWeb.ConnCase
  use Placebo
  alias Raptor.Services.DatasetStore
  alias Raptor.Schemas.Dataset

  @namespace "raptor:datasets:"
  @redix Raptor.Application.redis_client()

  describe "get_all/0" do
    test "returns empty list when no datasets in redis" do
      allow(Redix.command!(@redix, ["KEYS", @namespace <> "*"]), return: [])

      actualDatasets = DatasetStore.get_all()

      assert [] == actualDatasets
    end

    test "returns list of Raptor datasets when datasets in redis" do
      keys = ["raptor:datasets:system__name", "raptor:datasets:system__name_2"]
      allow(Redix.command!(@redix, ["KEYS", @namespace <> "*"]), return: keys)

      allow(Redix.command!(@redix, ["MGET" | keys]),
        return: [
          "{\"dataset_id\":\"1\",\"is_private\":false,\"org_id\":\"system\",\"system_name\":\"system__name\"}",
          "{\"dataset_id\":\"2\",\"is_private\":true,\"org_id\":\"system\",\"system_name\":\"system__name_2\"}"
        ]
      )

      expectedDatasets = [
        %Dataset{dataset_id: "1", system_name: "system__name", org_id: "system", is_private: false},
        %Dataset{dataset_id: "2", system_name: "system__name_2", org_id: "system", is_private: true}
      ]

      actualDatasets = DatasetStore.get_all()

      assert expectedDatasets == actualDatasets
    end
  end

  describe "get/1" do
    test "an empty map is returned when there are no entries in redis matching the system name" do
      system_name = "system__name"
      allow(Redix.command!(@redix, ["KEYS", @namespace <> system_name]), return: [])

      actualDataset = DatasetStore.get(system_name)

      assert %{} == actualDataset
    end

    test "a Raptor dataset is returned when there is one entry in redis matching the system name" do
      system_name = "system__name"

      allow(Redix.command!(@redix, ["KEYS", @namespace <> system_name]),
        return: ["raptor:datasets:system__name"]
      )

      allow(Redix.command!(@redix, ["MGET", "raptor:datasets:system__name"]),
        return: [
          "{\"dataset_id\":\"1\",\"is_private\":false,\"org_id\":\"system\",\"system_name\":\"system__name\"}"
        ]
      )

      expected_dataset = %Dataset{dataset_id: "1", system_name: "system__name", org_id: "system", is_private: false}

      actualDataset = DatasetStore.get(system_name)

      assert expected_dataset == actualDataset
    end

    test "an empty map is returned when there are multiple entries in redis matching the system name" do
      system_name = "system__name"
      keys = ["raptor:datasets:system__name", "raptor:datasets:system__name1"]
      allow(Redix.command!(@redix, ["KEYS", @namespace <> system_name]), return: keys)

      actualDatasets = DatasetStore.get(system_name)

      assert %{} == actualDatasets
    end
  end

  describe "persist/1" do
    test "Redis is successfully called with a dataset" do
      dataset = %Dataset{dataset_id: "1", system_name: "system__name", org_id: "system", is_private: false}

      dataset_json =
        "{\"dataset_id\":\"1\",\"is_private\":false,\"org_id\":\"system\",\"system_name\":\"system__name\"}"

      allow(Redix.command!(@redix, ["SET", @namespace <> "system__name", dataset_json]),
        return: :ok
      )

      DatasetStore.persist(dataset)

      assert_called(Redix.command!(@redix, ["SET", @namespace <> "system__name", dataset_json]))
    end
  end
end

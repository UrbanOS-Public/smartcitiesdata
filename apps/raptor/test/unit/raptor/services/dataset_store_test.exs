defmodule Raptor.Services.DatasetStoreTest do
  use RaptorWeb.ConnCase
  import Mock
  alias Raptor.Services.DatasetStore
  alias Raptor.Schemas.Dataset

  @namespace "raptor:datasets:"
  @redix Raptor.Application.redis_client()

  describe "get_all/0" do
    test "returns empty list when no datasets in redis" do
      with_mock Redix, [command!: fn(_, _) -> [] end] do
        actualDatasets = DatasetStore.get_all()
        assert [] == actualDatasets
      end
    end

    test "returns list of Raptor datasets when datasets in redis" do
      keys = ["raptor:datasets:system__name", "raptor:datasets:system__name_2"]
      
      expectedDatasets = [
        %Dataset{
          dataset_id: "1",
          system_name: "system__name",
          org_id: "system",
          is_private: false
        },
        %Dataset{
          dataset_id: "2",
          system_name: "system__name_2",
          org_id: "system",
          is_private: true
        }
      ]

      with_mock Redix, [
        command!: fn
          (_, ["KEYS", @namespace <> "*"]) -> keys
          (_, ["MGET" | ^keys]) -> [
            "{\"dataset_id\":\"1\",\"is_private\":false,\"org_id\":\"system\",\"system_name\":\"system__name\"}",
            "{\"dataset_id\":\"2\",\"is_private\":true,\"org_id\":\"system\",\"system_name\":\"system__name_2\"}"
          ]
        end
      ] do
        actualDatasets = DatasetStore.get_all()
        assert expectedDatasets == actualDatasets
      end
    end
  end

  describe "get/1" do
    test "an empty map is returned when there are no entries in redis matching the system name" do
      system_name = "system__name"
      
      with_mock Redix, [command!: fn(_, ["KEYS", @namespace <> ^system_name]) -> [] end] do
        actualDataset = DatasetStore.get(system_name)
        assert %{} == actualDataset
      end
    end

    test "a Raptor dataset is returned when there is one entry in redis matching the system name" do
      system_name = "system__name"
      key = "raptor:datasets:system__name"
      
      expected_dataset = %Dataset{
        dataset_id: "1",
        system_name: "system__name",
        org_id: "system",
        is_private: false
      }

      with_mock Redix, [
        command!: fn
          (_, ["KEYS", @namespace <> ^system_name]) -> [key]
          (_, ["MGET", ^key]) -> [
            "{\"dataset_id\":\"1\",\"is_private\":false,\"org_id\":\"system\",\"system_name\":\"system__name\"}"
          ]
        end
      ] do
        actualDataset = DatasetStore.get(system_name)
        assert expected_dataset == actualDataset
      end
    end

    test "an empty map is returned when there are multiple entries in redis matching the system name" do
      system_name = "system__name"
      keys = ["raptor:datasets:system__name", "raptor:datasets:system__name1"]
      
      with_mock Redix, [command!: fn(_, ["KEYS", @namespace <> ^system_name]) -> keys end] do
        actualDatasets = DatasetStore.get(system_name)
        assert %{} == actualDatasets
      end
    end
  end

  describe "persist/1" do
    test "Redis is successfully called with a dataset" do
      dataset = %Dataset{
        dataset_id: "1",
        system_name: "system__name",
        org_id: "system",
        is_private: false
      }

      dataset_json =
        "{\"dataset_id\":\"1\",\"is_private\":false,\"org_id\":\"system\",\"system_name\":\"system__name\"}"
      
      redis_key = @namespace <> "system__name"
      
      with_mock Redix, [command!: fn(_, ["SET", ^redis_key, ^dataset_json]) -> :ok end] do
        DatasetStore.persist(dataset)
        assert called(Redix.command!(@redix, ["SET", redis_key, dataset_json]))
      end
    end
  end
end

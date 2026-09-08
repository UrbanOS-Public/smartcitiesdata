defmodule Raptor.Services.DatasetAccessGroupRelationStoreTest do
  use RaptorWeb.ConnCase
  import Mock
  alias Raptor.Services.DatasetAccessGroupRelationStore
  alias Raptor.Schemas.DatasetAccessGroupRelation

  @namespace "raptor:dataset_access_group_relation:"
  @index_namespace "raptor:dataset_access_group_relation:index:"
  @redix Raptor.Application.redis_client()

  describe "get_all_by_dataset/1" do
    test "returns empty list when no index entries exist in redis" do
      dataset_id = "picard"

      with_mock Redix,
        command!: fn _, ["SMEMBERS", @index_namespace <> ^dataset_id] -> [] end do
        actualRelations = DatasetAccessGroupRelationStore.get_all_by_dataset(dataset_id)
        assert [] == actualRelations
      end
    end

    test "returns list of access_group_ids from the index when they exist in redis" do
      dataset_id = "picard"

      with_mock Redix,
        command!: fn _, ["SMEMBERS", @index_namespace <> ^dataset_id] -> ["enterprise"] end do
        actualRelations = DatasetAccessGroupRelationStore.get_all_by_dataset(dataset_id)
        assert ["enterprise"] == actualRelations
      end
    end
  end

  describe "get_all/0" do
    test "returns empty list when no dataset access group relations in redis" do
      with_mock Redix,
        command!: fn _, ["SCAN", "0", "MATCH", @namespace <> "*", "COUNT", 500] -> ["0", []] end do
        actualRelations = DatasetAccessGroupRelationStore.get_all()
        assert [] == actualRelations
      end
    end

    test "returns list of dataset-access_group relations when they exist in redis" do
      keys = [
        "raptor:dataset_access_group_relation:dataset_id:access_group_id",
        "raptor:dataset_access_group_relation:dataset_id1:access_group_id1"
      ]

      expectedRelations = [
        %DatasetAccessGroupRelation{dataset_id: "dataset_id", access_group_id: "access_group_id"},
        %DatasetAccessGroupRelation{
          dataset_id: "dataset_id1",
          access_group_id: "access_group_id1"
        }
      ]

      with_mock Redix,
        command!: fn
          _, ["SCAN", "0", "MATCH", @namespace <> "*", "COUNT", 500] ->
            ["0", keys]

          _, ["MGET" | ^keys] ->
            [
              "{\"dataset_id\":\"dataset_id\",\"access_group_id\":\"access_group_id\"}",
              "{\"dataset_id\":\"dataset_id1\",\"access_group_id\":\"access_group_id1\"}"
            ]
        end do
        actualRelations = DatasetAccessGroupRelationStore.get_all()
        assert expectedRelations == actualRelations
      end
    end
  end

  describe "get/1" do
    test "an empty map is returned when there are no entries in redis matching the datasetId and accessGroupId" do
      dataset_id = "picard"
      access_group_id = "enterprise"
      key = "#{dataset_id}:#{access_group_id}"

      with_mock Redix, command!: fn _, ["GET", @namespace <> ^key] -> nil end do
        actualRelation = DatasetAccessGroupRelationStore.get(dataset_id, access_group_id)
        assert %{} == actualRelation
      end
    end

    test "a Raptor dataset access group assoc is returned when there is one entry in redis matching the dataset id and access group id" do
      dataset_id = "picard"
      access_group_id = "enterprise"
      key = "#{dataset_id}:#{access_group_id}"

      expected_relation = %DatasetAccessGroupRelation{
        dataset_id: "picard",
        access_group_id: "enterprise"
      }

      with_mock Redix,
        command!: fn _, ["GET", @namespace <> ^key] ->
          "{\"dataset_id\":\"picard\",\"access_group_id\":\"enterprise\"}"
        end do
        actual_relation = DatasetAccessGroupRelationStore.get(dataset_id, access_group_id)
        assert expected_relation == actual_relation
      end
    end
  end

  describe "persist/1" do
    test "Redis is successfully called with a dataset access group relation entry" do
      dataset_id = "picard"
      access_group_id = "enterprise"

      dataset_access_group_relation = %DatasetAccessGroupRelation{
        dataset_id: "picard",
        access_group_id: "enterprise"
      }

      dataset_access_group_relation_json =
        "{\"access_group_id\":\"enterprise\",\"dataset_id\":\"picard\"}"

      redis_key = @namespace <> "#{dataset_id}:#{access_group_id}"
      index_key = @index_namespace <> dataset_id

      with_mock Redix,
        command!: fn
          _, ["SET", ^redis_key, ^dataset_access_group_relation_json] -> :ok
          _, ["SADD", ^index_key, ^access_group_id] -> 1
        end do
        DatasetAccessGroupRelationStore.persist(dataset_access_group_relation)

        assert called(
                 Redix.command!(@redix, [
                   "SET",
                   redis_key,
                   dataset_access_group_relation_json
                 ])
               )

        assert called(Redix.command!(@redix, ["SADD", index_key, access_group_id]))
      end
    end
  end

  describe "delete/1" do
    test "Redis' delete is successfully called with a dataset access group disassoc entry" do
      dataset_id = "picard"
      access_group_id = "enterprise"

      datasetAccessGroupRelation = %DatasetAccessGroupRelation{
        dataset_id: "picard",
        access_group_id: "enterprise"
      }

      redis_key = @namespace <> "#{dataset_id}:#{access_group_id}"
      index_key = @index_namespace <> dataset_id

      with_mock Redix,
        command!: fn
          _, ["DEL", ^redis_key] -> :ok
          _, ["SREM", ^index_key, ^access_group_id] -> 1
        end do
        DatasetAccessGroupRelationStore.delete(datasetAccessGroupRelation)
        assert called(Redix.command!(@redix, ["DEL", redis_key]))
        assert called(Redix.command!(@redix, ["SREM", index_key, access_group_id]))
      end
    end
  end
end

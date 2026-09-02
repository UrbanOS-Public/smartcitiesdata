defmodule Raptor.Services.DatasetAccessGroupRelationStoreTest do
  use RaptorWeb.ConnCase
  use Placebo
  alias Raptor.Services.DatasetAccessGroupRelationStore
  alias Raptor.Schemas.DatasetAccessGroupRelation

  @namespace "raptor:dataset_access_group_relation:"
  @index_namespace "raptor:dataset_access_group_relation:index:"
  @redix Raptor.Application.redis_client()

  describe "get_all_by_dataset/1" do
    test "returns empty list when no index entries exist in redis" do
      dataset_id = "picard"
      allow(Redix.command!(@redix, ["SMEMBERS", @index_namespace <> dataset_id]), return: [])

      actualRelations = DatasetAccessGroupRelationStore.get_all_by_dataset(dataset_id)

      assert [] == actualRelations
    end

    test "returns list of access_group_ids from the index when they exist in redis" do
      dataset_id = "picard"

      allow(Redix.command!(@redix, ["SMEMBERS", @index_namespace <> dataset_id]),
        return: ["enterprise"]
      )

      actualRelations = DatasetAccessGroupRelationStore.get_all_by_dataset(dataset_id)

      assert ["enterprise"] == actualRelations
    end
  end

  describe "get_all/0" do
    test "returns empty list when no dataset access group relations in redis" do
      allow(Redix.command!(@redix, ["SCAN", "0", "MATCH", @namespace <> "*", "COUNT", 500]),
        return: ["0", []]
      )

      actualRelations = DatasetAccessGroupRelationStore.get_all()

      assert [] == actualRelations
    end

    test "returns list of dataset-access_group relations when they exist in redis" do
      keys = [
        "raptor:dataset_access_group_relation:dataset_id:access_group_id",
        "raptor:dataset_access_group_relation:dataset_id1:access_group_id1"
      ]

      allow(Redix.command!(@redix, ["SCAN", "0", "MATCH", @namespace <> "*", "COUNT", 500]),
        return: ["0", keys]
      )

      allow(Redix.command!(@redix, ["MGET" | keys]),
        return: [
          "{\"dataset_id\":\"dataset_id\",\"access_group_id\":\"access_group_id\"}",
          "{\"dataset_id\":\"dataset_id1\",\"access_group_id\":\"access_group_id1\"}"
        ]
      )

      expectedRelations = [
        %DatasetAccessGroupRelation{dataset_id: "dataset_id", access_group_id: "access_group_id"},
        %DatasetAccessGroupRelation{
          dataset_id: "dataset_id1",
          access_group_id: "access_group_id1"
        }
      ]

      actualRelations = DatasetAccessGroupRelationStore.get_all()

      assert expectedRelations == actualRelations
    end
  end

  describe "get/1" do
    test "an empty map is returned when there are no entries in redis matching the datasetId and accessGroupId" do
      dataset_id = "picard"
      access_group_id = "enterprise"
      key = "#{dataset_id}:#{access_group_id}"
      allow(Redix.command!(@redix, ["GET", @namespace <> key]), return: nil)

      actualRelation = DatasetAccessGroupRelationStore.get(dataset_id, access_group_id)

      assert %{} == actualRelation
    end

    test "a Raptor dataset access group assoc is returned when there is one entry in redis matching the dataset id and access group id" do
      dataset_id = "picard"
      access_group_id = "enterprise"
      key = "#{dataset_id}:#{access_group_id}"

      allow(Redix.command!(@redix, ["GET", @namespace <> key]),
        return: "{\"dataset_id\":\"picard\",\"access_group_id\":\"enterprise\"}"
      )

      expected_relation = %DatasetAccessGroupRelation{
        dataset_id: "picard",
        access_group_id: "enterprise"
      }

      actual_relation = DatasetAccessGroupRelationStore.get(dataset_id, access_group_id)

      assert expected_relation == actual_relation
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

      allow(
        Redix.command!(@redix, [
          "SET",
          @namespace <> "#{dataset_id}:#{access_group_id}",
          dataset_access_group_relation_json
        ]),
        return: :ok
      )

      allow(
        Redix.command!(@redix, ["SADD", @index_namespace <> dataset_id, access_group_id]),
        return: 1
      )

      DatasetAccessGroupRelationStore.persist(dataset_access_group_relation)

      assert_called(
        Redix.command!(@redix, [
          "SET",
          @namespace <> "#{dataset_id}:#{access_group_id}",
          dataset_access_group_relation_json
        ])
      )

      assert_called(
        Redix.command!(@redix, ["SADD", @index_namespace <> dataset_id, access_group_id])
      )
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

      allow(Redix.command!(@redix, ["DEL", @namespace <> "#{dataset_id}:#{access_group_id}"]),
        return: :ok
      )

      allow(
        Redix.command!(@redix, ["SREM", @index_namespace <> dataset_id, access_group_id]),
        return: 1
      )

      DatasetAccessGroupRelationStore.delete(datasetAccessGroupRelation)

      assert_called(
        Redix.command!(@redix, ["DEL", @namespace <> "#{dataset_id}:#{access_group_id}"])
      )

      assert_called(
        Redix.command!(@redix, ["SREM", @index_namespace <> dataset_id, access_group_id])
      )
    end
  end
end

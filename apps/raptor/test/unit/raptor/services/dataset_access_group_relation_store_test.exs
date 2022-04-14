defmodule Raptor.Services.DatasetAccessGroupRelationStoreTest do
  use RaptorWeb.ConnCase
  use Placebo
  alias Raptor.Services.DatasetAccessGroupRelationStore
  alias Raptor.Schemas.DatasetAccessGroupRelation

  @namespace "raptor:dataset_access_group_relation:"
  @redix Raptor.Application.redis_client()

  describe "get_all/0" do
    test "returns empty list when no dataset access group relations in redis" do
      allow(Redix.command!(@redix, ["KEYS", @namespace <> "*"]), return: [])

      actualRelations = DatasetAccessGroupRelationStore.get_all()

      assert [] == actualRelations
    end

    test "returns list of dataset-access_group relations when they exist in redis" do
      keys = [
        "raptor:dataset_access_group_relation:dataset_id:access_group_id",
        "raptor:dataset_access_group_relation:dataset_id1:access_group_id1"
      ]

      allow(Redix.command!(@redix, ["KEYS", @namespace <> "*"]), return: keys)

      allow(Redix.command!(@redix, ["MGET" | keys]),
        return: [
          "{\"dataset_id\":\"dataset_id\",\"access_group_id\":\"access_group_id\"}",
          "{\"dataset_id\":\"dataset_id1\",\"access_group_id\":\"access_group_id1\"}"
        ]
      )

      expectedRelations = [
        %DatasetAccessGroupRelation{dataset_id: "dataset_id", access_group_id: "access_group_id"},
        %DatasetAccessGroupRelation{dataset_id: "dataset_id1", access_group_id: "access_group_id1"}
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
      allow(Redix.command!(@redix, ["KEYS", @namespace <> key]), return: [])

      actualRelation = DatasetAccessGroupRelationStore.get(dataset_id, access_group_id)

      assert %{} == actualRelation
    end

    test "a Raptor dataset access group assoc is returned when there is one entry in redis matching the dataset id and access group id" do
      dataset_id = "picard"
      access_group_id = "enterprise"
      key = "#{dataset_id}:#{access_group_id}"

      allow(Redix.command!(@redix, ["KEYS", @namespace <> key]),
        return: ["raptor:dataset_access_group_relation:picard:enterprise"]
      )

      allow(
        Redix.command!(@redix, ["MGET", "raptor:dataset_access_group_relation:picard:enterprise"]),
        return: [
          "{\"dataset_id\":\"picard\",\"access_group_id\":\"enterprise\"}"
        ]
      )

      expected_relation = %DatasetAccessGroupRelation{
        dataset_id: "picard",
        access_group_id: "enterprise"
      }

      actual_relation = DatasetAccessGroupRelationStore.get(dataset_id, access_group_id)

      assert expected_relation == actual_relation
    end

    test "an empty map is returned when there are multiple entries in redis matching the dataset id and access group id" do
      dataset_id = "picard"
      access_group_id = "enterprise"

      keys = [
        "raptor:dataset_access_group_relation:picard:enterprise",
        "raptor:dataset_access_group_relation:picard:enterprise"
      ]

      allow(Redix.command!(@redix, ["KEYS", @namespace <> "#{dataset_id}:#{access_group_id}"]),
        return: keys
      )

      actual_relation = DatasetAccessGroupRelationStore.get(dataset_id, access_group_id)

      assert %{} == actual_relation
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

      DatasetAccessGroupRelationStore.persist(dataset_access_group_relation)

      assert_called(
        Redix.command!(@redix, [
          "SET",
          @namespace <> "#{dataset_id}:#{access_group_id}",
          dataset_access_group_relation_json
        ])
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

      DatasetAccessGroupRelationStore.delete(datasetAccessGroupRelation)

      assert_called(
        Redix.command!(@redix, ["DEL", @namespace <> "#{dataset_id}:#{access_group_id}"])
      )
    end
  end
end

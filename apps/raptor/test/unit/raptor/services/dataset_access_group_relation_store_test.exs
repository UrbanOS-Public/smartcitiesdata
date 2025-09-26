defmodule Raptor.Services.DatasetAccessGroupRelationStoreTest do
  use RaptorWeb.ConnCase
  import Mock
  alias Raptor.Services.DatasetAccessGroupRelationStore
  alias Raptor.Schemas.DatasetAccessGroupRelation

  @namespace "raptor:dataset_access_group_relation:"
  @redix Raptor.Application.redis_client()

  describe "get_all/0" do
    test "returns empty list when no dataset access group relations in redis" do
      with_mock Redix, command!: fn _, ["KEYS", @namespace <> "*"] -> [] end do
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
          _, ["KEYS", @namespace <> "*"] ->
            keys

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

      with_mock Redix, command!: fn _, ["KEYS", @namespace <> ^key] -> [] end do
        actualRelation = DatasetAccessGroupRelationStore.get(dataset_id, access_group_id)
        assert %{} == actualRelation
      end
    end

    test "a Raptor dataset access group assoc is returned when there is one entry in redis matching the dataset id and access group id" do
      dataset_id = "picard"
      access_group_id = "enterprise"
      key = "#{dataset_id}:#{access_group_id}"
      redis_key = "raptor:dataset_access_group_relation:picard:enterprise"

      expected_relation = %DatasetAccessGroupRelation{
        dataset_id: "picard",
        access_group_id: "enterprise"
      }

      with_mock Redix,
        command!: fn
          _, ["KEYS", @namespace <> ^key] ->
            [redis_key]

          _, ["MGET", ^redis_key] ->
            [
              "{\"dataset_id\":\"picard\",\"access_group_id\":\"enterprise\"}"
            ]
        end do
        actual_relation = DatasetAccessGroupRelationStore.get(dataset_id, access_group_id)
        assert expected_relation == actual_relation
      end
    end

    test "an empty map is returned when there are multiple entries in redis matching the dataset id and access group id" do
      dataset_id = "picard"
      access_group_id = "enterprise"
      key = "#{dataset_id}:#{access_group_id}"

      keys = [
        "raptor:dataset_access_group_relation:picard:enterprise",
        "raptor:dataset_access_group_relation:picard:enterprise"
      ]

      with_mock Redix, command!: fn _, ["KEYS", @namespace <> ^key] -> keys end do
        actual_relation = DatasetAccessGroupRelationStore.get(dataset_id, access_group_id)
        assert %{} == actual_relation
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

      with_mock Redix,
        command!: fn _,
                     [
                       "SET",
                       ^redis_key,
                       ^dataset_access_group_relation_json
                     ] ->
          :ok
        end do
        DatasetAccessGroupRelationStore.persist(dataset_access_group_relation)

        assert called(
                 Redix.command!(@redix, [
                   "SET",
                   redis_key,
                   dataset_access_group_relation_json
                 ])
               )
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

      with_mock Redix, command!: fn _, ["DEL", ^redis_key] -> :ok end do
        DatasetAccessGroupRelationStore.delete(datasetAccessGroupRelation)
        assert called(Redix.command!(@redix, ["DEL", redis_key]))
      end
    end
  end
end

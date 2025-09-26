defmodule Raptor.Services.UserAccessGroupRelationStoreTest do
  use RaptorWeb.ConnCase
  import Mock
  alias Raptor.Services.UserAccessGroupRelationStore
  alias Raptor.Schemas.UserAccessGroupRelation

  @namespace "raptor:user_access_group_relation:"
  @redix Raptor.Application.redis_client()

  describe "get_all/0" do
    test "returns empty list when no user access group relations in redis" do
      with_mock Redix, command!: fn _, ["KEYS", @namespace <> "*"] -> [] end do
        actualRelations = UserAccessGroupRelationStore.get_all()
        assert [] == actualRelations
      end
    end

    test "returns list of user-access_group relations when they exist in redis" do
      keys = [
        "raptor:user_access_group_relation:user_id:access_group_id",
        "raptor:user_access_group_relation:user_id1:access_group_id1"
      ]

      expectedRelations = [
        %UserAccessGroupRelation{user_id: "user_id", access_group_id: "access_group_id"},
        %UserAccessGroupRelation{user_id: "user_id1", access_group_id: "access_group_id1"}
      ]

      with_mock Redix,
        command!: fn
          _, ["KEYS", @namespace <> "*"] ->
            keys

          _, ["MGET" | ^keys] ->
            [
              "{\"user_id\":\"user_id\",\"access_group_id\":\"access_group_id\"}",
              "{\"user_id\":\"user_id1\",\"access_group_id\":\"access_group_id1\"}"
            ]
        end do
        actualRelations = UserAccessGroupRelationStore.get_all()
        assert expectedRelations == actualRelations
      end
    end
  end

  describe "get/1" do
    test "an empty map is returned when there are no entries in redis matching the userId and accessGroupId" do
      user_id = "picard"
      access_group_id = "enterprise"
      key = "#{user_id}:#{access_group_id}"

      with_mock Redix, command!: fn _, ["KEYS", @namespace <> ^key] -> [] end do
        actualRelation = UserAccessGroupRelationStore.get(user_id, access_group_id)
        assert %{} == actualRelation
      end
    end

    test "a Raptor user access group assoc is returned when there is one entry in redis matching the user id and access group id" do
      user_id = "picard"
      access_group_id = "enterprise"
      key = "#{user_id}:#{access_group_id}"
      redis_key = "raptor:user_access_group_relation:picard:enterprise"

      expected_relation = %UserAccessGroupRelation{
        user_id: "picard",
        access_group_id: "enterprise"
      }

      with_mock Redix,
        command!: fn
          _, ["KEYS", @namespace <> ^key] ->
            [redis_key]

          _, ["MGET", ^redis_key] ->
            [
              "{\"user_id\":\"picard\",\"access_group_id\":\"enterprise\"}"
            ]
        end do
        actual_relation = UserAccessGroupRelationStore.get(user_id, access_group_id)
        assert expected_relation == actual_relation
      end
    end

    test "an empty map is returned when there are multiple entries in redis matching the user id and access group id" do
      user_id = "picard"
      access_group_id = "enterprise"
      key = "#{user_id}:#{access_group_id}"

      keys = [
        "raptor:user_access_group_relation:picard:enterprise",
        "raptor:user_access_group_relation:picard:enterprise"
      ]

      with_mock Redix, command!: fn _, ["KEYS", @namespace <> ^key] -> keys end do
        actual_relation = UserAccessGroupRelationStore.get(user_id, access_group_id)
        assert %{} == actual_relation
      end
    end
  end

  describe "persist/1" do
    test "Redis is successfully called with a user access group relation entry" do
      user_id = "picard"
      access_group_id = "enterprise"

      user_access_group_relation = %UserAccessGroupRelation{
        user_id: "picard",
        access_group_id: "enterprise"
      }

      user_access_group_relation_json =
        "{\"access_group_id\":\"enterprise\",\"user_id\":\"picard\"}"

      redis_key = @namespace <> "#{user_id}:#{access_group_id}"

      with_mock Redix,
        command!: fn _,
                     [
                       "SET",
                       ^redis_key,
                       ^user_access_group_relation_json
                     ] ->
          :ok
        end do
        UserAccessGroupRelationStore.persist(user_access_group_relation)

        assert called(
                 Redix.command!(@redix, [
                   "SET",
                   redis_key,
                   user_access_group_relation_json
                 ])
               )
      end
    end
  end

  describe "delete/1" do
    test "Redis' delete is successfully called with a user access group disassoc entry" do
      user_id = "picard"
      access_group_id = "enterprise"

      userAccessGroupRelation = %UserAccessGroupRelation{
        user_id: "picard",
        access_group_id: "enterprise"
      }

      redis_key = @namespace <> "#{user_id}:#{access_group_id}"

      with_mock Redix, command!: fn _, ["DEL", ^redis_key] -> :ok end do
        UserAccessGroupRelationStore.delete(userAccessGroupRelation)
        assert called(Redix.command!(@redix, ["DEL", redis_key]))
      end
    end
  end
end

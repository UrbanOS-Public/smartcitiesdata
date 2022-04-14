defmodule Raptor.Services.UserAccessGroupRelationStoreTest do
  use RaptorWeb.ConnCase
  use Placebo
  alias Raptor.Services.UserAccessGroupRelationStore
  alias Raptor.Schemas.UserAccessGroupRelation

  @namespace "raptor:user_access_group_relation:"
  @redix Raptor.Application.redis_client()

  describe "get_all/0" do
    test "returns empty list when no user access group relations in redis" do
      allow(Redix.command!(@redix, ["KEYS", @namespace <> "*"]), return: [])

      actualRelations = UserAccessGroupRelationStore.get_all()

      assert [] == actualRelations
    end

    test "returns list of user-access_group relations when they exist in redis" do
      keys = [
        "raptor:user_access_group_relation:user_id:access_group_id",
        "raptor:user_access_group_relation:user_id1:access_group_id1"
      ]

      allow(Redix.command!(@redix, ["KEYS", @namespace <> "*"]), return: keys)

      allow(Redix.command!(@redix, ["MGET" | keys]),
        return: [
          "{\"user_id\":\"user_id\",\"access_group_id\":\"access_group_id\"}",
          "{\"user_id\":\"user_id1\",\"access_group_id\":\"access_group_id1\"}"
        ]
      )

      expectedRelations = [
        %UserAccessGroupRelation{user_id: "user_id", access_group_id: "access_group_id"},
        %UserAccessGroupRelation{user_id: "user_id1", access_group_id: "access_group_id1"}
      ]

      actualRelations = UserAccessGroupRelationStore.get_all()

      assert expectedRelations == actualRelations
    end
  end

  describe "get/1" do
    test "an empty map is returned when there are no entries in redis matching the userId and accessGroupId" do
      user_id = "picard"
      access_group_id = "enterprise"
      key = "#{user_id}:#{access_group_id}"
      allow(Redix.command!(@redix, ["KEYS", @namespace <> key]), return: [])

      actualRelation = UserAccessGroupRelationStore.get(user_id, access_group_id)

      assert %{} == actualRelation
    end

    test "a Raptor user access group assoc is returned when there is one entry in redis matching the user id and access group id" do
      user_id = "picard"
      access_group_id = "enterprise"
      key = "#{user_id}:#{access_group_id}"

      allow(Redix.command!(@redix, ["KEYS", @namespace <> key]),
        return: ["raptor:user_access_group_relation:picard:enterprise"]
      )

      allow(
        Redix.command!(@redix, ["MGET", "raptor:user_access_group_relation:picard:enterprise"]),
        return: [
          "{\"user_id\":\"picard\",\"access_group_id\":\"enterprise\"}"
        ]
      )

      expected_relation = %UserAccessGroupRelation{
        user_id: "picard",
        access_group_id: "enterprise"
      }

      actual_relation = UserAccessGroupRelationStore.get(user_id, access_group_id)

      assert expected_relation == actual_relation
    end

    test "an empty map is returned when there are multiple entries in redis matching the user id and access group id" do
      user_id = "picard"
      access_group_id = "enterprise"

      keys = [
        "raptor:user_access_group_relation:picard:enterprise",
        "raptor:user_access_group_relation:picard:enterprise"
      ]

      allow(Redix.command!(@redix, ["KEYS", @namespace <> "#{user_id}:#{access_group_id}"]),
        return: keys
      )

      actual_relation = UserAccessGroupRelationStore.get(user_id, access_group_id)

      assert %{} == actual_relation
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

      allow(
        Redix.command!(@redix, [
          "SET",
          @namespace <> "#{user_id}:#{access_group_id}",
          user_access_group_relation_json
        ]),
        return: :ok
      )

      UserAccessGroupRelationStore.persist(user_access_group_relation)

      assert_called(
        Redix.command!(@redix, [
          "SET",
          @namespace <> "#{user_id}:#{access_group_id}",
          user_access_group_relation_json
        ])
      )
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

      allow(Redix.command!(@redix, ["DEL", @namespace <> "#{user_id}:#{access_group_id}"]),
        return: :ok
      )

      UserAccessGroupRelationStore.delete(userAccessGroupRelation)

      assert_called(
        Redix.command!(@redix, ["DEL", @namespace <> "#{user_id}:#{access_group_id}"])
      )
    end
  end
end

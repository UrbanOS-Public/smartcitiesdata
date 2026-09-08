defmodule Raptor.Services.UserOrgAssocStoreTest do
  use RaptorWeb.ConnCase
  import Mock
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.Schemas.UserOrgAssoc

  @namespace "raptor:user_org_assoc:"
  @index_namespace "raptor:user_org_assoc:index:"
  @redix Raptor.Application.redis_client()

  describe "get_all/0" do
    test "returns empty list when no datasets in redis" do
      with_mock Redix,
        command!: fn _, ["SCAN", "0", "MATCH", @namespace <> "*", "COUNT", 500] -> ["0", []] end do
        actualDatasets = UserOrgAssocStore.get_all()
        assert [] == actualDatasets
      end
    end

    test "returns list of user-org associations when they exist in redis" do
      keys = ["raptor:user_org_assoc:user_id:org_id", "raptor:user_org_assoc:user_id1:org_id1"]

      expectedDatasets = [
        %UserOrgAssoc{user_id: "user_id", email: "hazel@starfleet.com", org_id: "org_id"},
        %UserOrgAssoc{user_id: "user_id1", email: "penny@starfleet.com", org_id: "org_id1"}
      ]

      with_mock Redix,
        command!: fn
          _, ["SCAN", "0", "MATCH", @namespace <> "*", "COUNT", 500] ->
            ["0", keys]

          _, ["MGET" | ^keys] ->
            [
              "{\"user_id\":\"user_id\",\"org_id\":\"org_id\",\"email\":\"hazel@starfleet.com\"}",
              "{\"user_id\":\"user_id1\",\"org_id\":\"org_id1\",\"email\":\"penny@starfleet.com\"}"
            ]
        end do
        actualDatasets = UserOrgAssocStore.get_all()
        assert expectedDatasets == actualDatasets
      end
    end
  end

  describe "get/1" do
    test "an empty map is returned when there are no entries in redis matching the userId and orgId" do
      user_id = "picard"
      org_id = "enterprise"
      key = "#{user_id}:#{org_id}"

      with_mock Redix, command!: fn _, ["GET", @namespace <> ^key] -> nil end do
        actualDataset = UserOrgAssocStore.get(user_id, org_id)
        assert %{} == actualDataset
      end
    end

    test "a Raptor user org assoc is returned when there is one entry in redis matching the user id and org id" do
      user_id = "picard"
      org_id = "enterprise"
      key = "#{user_id}:#{org_id}"

      expected_dataset = %UserOrgAssoc{
        user_id: "picard",
        email: "jeanluc@starfleet.com",
        org_id: "enterprise"
      }

      with_mock Redix,
        command!: fn _, ["GET", @namespace <> ^key] ->
          "{\"user_id\":\"picard\",\"org_id\":\"enterprise\",\"email\":\"jeanluc@starfleet.com\"}"
        end do
        actualDataset = UserOrgAssocStore.get(user_id, org_id)
        assert expected_dataset == actualDataset
      end
    end
  end

  describe "get_all_by_user/1" do
    test "an empty array is returned when there are no entries in redis matching the userId" do
      user_id = "picard"

      with_mock Redix,
        command!: fn _, ["SMEMBERS", @index_namespace <> ^user_id] -> [] end do
        response = UserOrgAssocStore.get_all_by_user(user_id)
        assert [] == response
      end
    end

    test "a Raptor user org assoc is returned when there is one entry in redis matching the user id " do
      user_id = "picard"

      with_mock Redix,
        command!: fn _, ["SMEMBERS", @index_namespace <> ^user_id] -> ["enterprise"] end do
        actual_response = UserOrgAssocStore.get_all_by_user(user_id)
        assert actual_response == ["enterprise"]
      end
    end
  end

  describe "persist/1" do
    test "Redis is successfully called with a user org assoc entry" do
      user_id = "picard"
      org_id = "enterprise"

      userOrgAssoc = %UserOrgAssoc{
        user_id: "picard",
        email: "jeanluc@starfleet.com",
        org_id: "enterprise"
      }

      user_org_assoc_json =
        "{\"email\":\"jeanluc@starfleet.com\",\"org_id\":\"enterprise\",\"user_id\":\"picard\"}"

      redis_key = @namespace <> "#{user_id}:#{org_id}"
      index_key = @index_namespace <> user_id

      with_mock Redix,
        command!: fn
          _, ["SET", ^redis_key, ^user_org_assoc_json] -> :ok
          _, ["SADD", ^index_key, ^org_id] -> 1
        end do
        UserOrgAssocStore.persist(userOrgAssoc)
        assert called(Redix.command!(@redix, ["SET", redis_key, user_org_assoc_json]))
        assert called(Redix.command!(@redix, ["SADD", index_key, org_id]))
      end
    end
  end

  describe "delete/1" do
    test "Redis' delete is successfully called with a user org disassoc entry" do
      user_id = "picard"
      org_id = "enterprise"
      userOrgAssoc = %UserOrgAssoc{user_id: "picard", email: nil, org_id: "enterprise"}

      redis_key = @namespace <> "#{user_id}:#{org_id}"
      index_key = @index_namespace <> user_id

      with_mock Redix,
        command!: fn
          _, ["DEL", ^redis_key] -> :ok
          _, ["SREM", ^index_key, ^org_id] -> 1
        end do
        UserOrgAssocStore.delete(userOrgAssoc)
        assert called(Redix.command!(@redix, ["DEL", redis_key]))
        assert called(Redix.command!(@redix, ["SREM", index_key, org_id]))
      end
    end
  end
end

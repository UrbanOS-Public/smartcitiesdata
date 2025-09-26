defmodule Raptor.Services.UserOrgAssocStoreTest do
  use RaptorWeb.ConnCase
  import Mock
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.Schemas.UserOrgAssoc

  @namespace "raptor:user_org_assoc:"
  @redix Raptor.Application.redis_client()

  describe "get_all/0" do
    test "returns empty list when no datasets in redis" do
      with_mock Redix, command!: fn _, ["KEYS", @namespace <> "*"] -> [] end do
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
          _, ["KEYS", @namespace <> "*"] ->
            keys

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

      with_mock Redix, command!: fn _, ["KEYS", @namespace <> ^key] -> [] end do
        actualDataset = UserOrgAssocStore.get(user_id, org_id)
        assert %{} == actualDataset
      end
    end

    test "a Raptor user org assoc is returned when there is one entry in redis matching the user id and org id" do
      user_id = "picard"
      org_id = "enterprise"
      key = "#{user_id}:#{org_id}"
      redis_key = "raptor:user_org_assoc:picard:enterprise"

      expected_dataset = %UserOrgAssoc{
        user_id: "picard",
        email: "jeanluc@starfleet.com",
        org_id: "enterprise"
      }

      with_mock Redix,
        command!: fn
          _, ["KEYS", @namespace <> ^key] ->
            [redis_key]

          _, ["MGET", ^redis_key] ->
            [
              "{\"user_id\":\"picard\",\"org_id\":\"enterprise\",\"email\":\"jeanluc@starfleet.com\"}"
            ]
        end do
        actualDataset = UserOrgAssocStore.get(user_id, org_id)
        assert expected_dataset == actualDataset
      end
    end

    test "an empty map is returned when there are multiple entries in redis matching the user id and org id" do
      user_id = "picard"
      org_id = "enterprise"
      key = "#{user_id}:#{org_id}"

      keys = [
        "raptor:user_org_assoc:picard:enterprise",
        "raptor:user_org_assoc:picard:enterprise"
      ]

      with_mock Redix, command!: fn _, ["KEYS", @namespace <> ^key] -> keys end do
        actualDatasets = UserOrgAssocStore.get(user_id, org_id)
        assert %{} == actualDatasets
      end
    end
  end

  describe "get_all_by_user/1" do
    test "an empty array is returned when there are no entries in redis matching the userId" do
      user_id = "picard"
      key = "#{user_id}:*"

      with_mock Redix, command!: fn _, ["KEYS", @namespace <> ^key] -> [] end do
        response = UserOrgAssocStore.get_all_by_user(user_id)
        assert [] == response
      end
    end

    test "a Raptor user org assoc is returned when there is one entry in redis matching the user id " do
      user_id = "picard"
      key = "#{user_id}:*"
      redis_key = "raptor:user_org_assoc:picard:enterprise"

      with_mock Redix,
        command!: fn
          _, ["KEYS", @namespace <> ^key] ->
            [redis_key]

          _, ["MGET", ^redis_key] ->
            [
              "{\"user_id\":\"picard\",\"org_id\":\"enterprise\",\"email\":\"jeanluc@starfleet.com\"}"
            ]
        end do
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

      with_mock Redix, command!: fn _, ["SET", ^redis_key, ^user_org_assoc_json] -> :ok end do
        UserOrgAssocStore.persist(userOrgAssoc)
        assert called(Redix.command!(@redix, ["SET", redis_key, user_org_assoc_json]))
      end
    end
  end

  describe "delete/1" do
    test "Redis' delete is successfully called with a user org disassoc entry" do
      user_id = "picard"
      org_id = "enterprise"
      userOrgAssoc = %UserOrgAssoc{user_id: "picard", email: nil, org_id: "enterprise"}

      redis_key = @namespace <> "#{user_id}:#{org_id}"

      with_mock Redix, command!: fn _, ["DEL", ^redis_key] -> :ok end do
        UserOrgAssocStore.delete(userOrgAssoc)
        assert called(Redix.command!(@redix, ["DEL", redis_key]))
      end
    end
  end
end

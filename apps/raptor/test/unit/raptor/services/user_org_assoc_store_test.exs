defmodule Raptor.Services.UserOrgAssocStoreTest do
    use RaptorWeb.ConnCase
    use Placebo
    alias Raptor.Services.UserOrgAssocStore
    alias Raptor.Schemas.UserOrgAssoc

    @namespace "raptor:user_org_assoc:"
    @redix Raptor.Application.redis_client()

    describe "get_all/0" do
      test "returns empty list when no datasets in redis", %{conn: conn} do
        allow(Redix.command!(@redix, ["KEYS", @namespace <> "*"]), return: [])

        actualDatasets = UserOrgAssocStore.get_all()

        assert [] == actualDatasets
      end

      test "returns list of user-org associations when they exist in redis", %{conn: conn} do
        keys = ["raptor:user_org_assoc:user_id:org_id", "raptor:user_org_assoc:user_id1:org_id1"]
        allow(Redix.command!(@redix, ["KEYS", @namespace <> "*"]), return: keys)

        allow(Redix.command!(@redix, ["MGET" | keys]),
          return: [
            "{\"user_id\":\"user_id\",\"org_id\":\"org_id\",\"email\":\"hazel@starfleet.com\"}",
            "{\"user_id\":\"user_id1\",\"org_id\":\"org_id1\",\"email\":\"penny@starfleet.com\"}"
          ]
        )

        expectedDatasets = [
          %UserOrgAssoc{user_id: "user_id", email: "hazel@starfleet.com", org_id: "org_id"},
          %UserOrgAssoc{user_id: "user_id1", email: "penny@starfleet.com", org_id: "org_id1"}
        ]

        actualDatasets = UserOrgAssocStore.get_all()

        assert expectedDatasets == actualDatasets
      end
    end

    describe "get/1" do
      test "an empty map is returned when there are no entries in redis matching the userId and orgId",
           %{conn: conn} do
        user_id = "picard"
        org_id = "enterprise"
        key ="#{user_id}:#{org_id}"
        allow(Redix.command!(@redix, ["KEYS", @namespace <> key]), return: [])

        actualDataset = UserOrgAssocStore.get(user_id, org_id)

        assert %{} == actualDataset
      end

      test "a Raptor user org assoc is returned when there is one entry in redis matching the user id and org id",
           %{conn: conn} do
        user_id = "picard"
        org_id = "enterprise"
        key ="#{user_id}:#{org_id}"

        allow(Redix.command!(@redix, ["KEYS", @namespace <> "#{user_id}:#{org_id}"]),
          return: ["raptor:user_org_assoc:picard:enterprise"]
        )

        allow(Redix.command!(@redix, ["MGET", "raptor:user_org_assoc:picard:enterprise"]),
          return: [
            "{\"user_id\":\"picard\",\"org_id\":\"enterprise\",\"email\":\"jeanluc@starfleet.com\"}"
          ]
        )

        expected_dataset = %UserOrgAssoc{user_id: "picard", email: "jeanluc@starfleet.com", org_id: "enterprise"}

        actualDataset = UserOrgAssocStore.get(user_id, org_id)

        assert expected_dataset == actualDataset
      end

      test "an empty map is returned when there are multiple entries in redis matching the user id and org id",
           %{conn: conn} do
        user_id = "picard"
        org_id = "enterprise"
        keys = ["raptor:user_org_assoc:picard:enterprise", "raptor:user_org_assoc:picard:enterprise"]
        allow(Redix.command!(@redix, ["KEYS", @namespace <> "#{user_id}:#{org_id}"]), return: keys)

        actualDatasets = UserOrgAssocStore.get(user_id, org_id)

        assert %{} == actualDatasets
      end
    end

    describe "persist/1" do
      test "Redis is successfully called with a user org assoc entry", %{conn: conn} do
        user_id = "picard"
        org_id = "enterprise"
        userOrgAssoc = %UserOrgAssoc{user_id: "picard", email: "jeanluc@starfleet.com", org_id: "enterprise"}
        user_org_assoc_json = "{\"email\":\"jeanluc@starfleet.com\",\"org_id\":\"enterprise\",\"user_id\":\"picard\"}"
        allow(Redix.command!(@redix, ["SET", @namespace <> "#{user_id}:#{org_id}", user_org_assoc_json]), return: :ok)
        UserOrgAssocStore.persist(userOrgAssoc)

        assert_called Redix.command!(@redix, ["SET", @namespace <> "#{user_id}:#{org_id}", user_org_assoc_json])
      end
    end

    describe "delete/1" do
        test "Redis' delete is successfully called with a user org disassoc entry", %{conn: conn} do
          user_id = "picard"
          org_id = "enterprise"
          userOrgAssoc = %UserOrgAssoc{user_id: "picard", email: nil, org_id: "enterprise"}
          allow(Redix.command!(@redix, ["DEL", @namespace <> "#{user_id}:#{org_id}"]), return: :ok)
          UserOrgAssocStore.delete(userOrgAssoc)

          assert_called Redix.command!(@redix, ["DEL", @namespace <> "#{user_id}:#{org_id}"])
        end
      end

  end

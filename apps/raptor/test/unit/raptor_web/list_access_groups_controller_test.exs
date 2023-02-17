defmodule RaptorWeb.ListAccessGroupsControllerTest do
  use RaptorWeb.ConnCase
  use Placebo
  alias Raptor.Services.DatasetStore
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.Services.DatasetAccessGroupRelationStore
  alias Raptor.Services.UserAccessGroupRelationStore
  alias Raptor.Services.Auth0Management
  alias Raptor.Schemas.Auth0UserData

  describe "retrieves access groups by api_key" do
    test "returns an empty list when there are no access groups for the given apiKey", %{
      conn: conn
    } do
      api_key = "ap1K3Y"
      user_id = "auth0_user"

      allow(Auth0Management.get_users_by_api_key(api_key),
        return: {:ok, [%Auth0UserData{user_id: user_id}]}
      )

      allow(UserOrgAssocStore.get_all_by_user("auth0_user"), return: [])

      expect(UserAccessGroupRelationStore.get_all_by_user(user_id),
        return: []
      )

      actual =
        conn
        |> get("/api/listAccessGroups?api_key=#{api_key}")
        |> json_response(200)

      expected = %{"access_groups" => [], "organizations" => []}

      assert actual == expected
    end

    test "returns a list of access groups when there are access groups for the given apiKey", %{
      conn: conn
    } do
      api_key = "ap1K3Y"
      user_id = "auth0_user"

      allow(Auth0Management.get_users_by_api_key(api_key),
        return: {:ok, [%Auth0UserData{user_id: user_id}]}
      )

      allow(UserOrgAssocStore.get_all_by_user("auth0_user"), return: [])

      expect(UserAccessGroupRelationStore.get_all_by_user(user_id),
        return: ["access_group1", "access_group2"]
      )

      actual =
        conn
        |> get("/api/listAccessGroups?api_key=#{api_key}")
        |> json_response(200)

      expected = %{"access_groups" => ["access_group1", "access_group2"], "organizations" => []}

      assert actual == expected
    end
  end

  describe "retrieves access groups by dataset_id" do
    test "returns an empty list when there are no access groups for the given dataset", %{
      conn: conn
    } do
      dataset_id = "dataset-without-access-groups"

      expect(DatasetAccessGroupRelationStore.get_all_by_dataset(dataset_id),
        return: []
      )

      actual =
        conn
        |> get("/api/listAccessGroups?dataset_id=#{dataset_id}")
        |> json_response(200)

      expected = %{"access_groups" => []}

      assert actual == expected
    end

    test "returns a list of access groups when there are access groups for the given dataset", %{
      conn: conn
    } do
      dataset_id = "dataset-without-access-groups"

      expect(DatasetAccessGroupRelationStore.get_all_by_dataset(dataset_id),
        return: ["access-group1", "access-group2"]
      )

      actual =
        conn
        |> get("/api/listAccessGroups?dataset_id=#{dataset_id}")
        |> json_response(200)

      expected = %{"access_groups" => ["access-group1", "access-group2"]}

      assert actual == expected
    end
  end

  describe "retrieves access groups by user_id" do
    test "returns an empty list when there are no access groups for the given user", %{conn: conn} do
      user_id = "user-without-access-groups"
      allow(UserOrgAssocStore.get_all_by_user(user_id), return: [])

      expect(UserAccessGroupRelationStore.get_all_by_user(user_id),
        return: []
      )

      actual =
        conn
        |> get("/api/listAccessGroups?user_id=#{user_id}")
        |> json_response(200)

      expected = %{"access_groups" => [], "organizations" => []}

      assert actual == expected
    end

    test "returns a list of access groups when there are access groups for the given user", %{
      conn: conn
    } do
      user_id = "user-with-access-groups"
      allow(UserOrgAssocStore.get_all_by_user(user_id), return: [])

      expect(UserAccessGroupRelationStore.get_all_by_user(user_id),
        return: ["access-group1", "access-group2"]
      )

      actual =
        conn
        |> get("/api/listAccessGroups?user_id=#{user_id}")
        |> json_response(200)

      expected = %{"access_groups" => ["access-group1", "access-group2"], "organizations" => []}

      assert actual == expected
    end
  end

  describe "error scenarios" do
    test "returns a 400 when invalid parameters are passed", %{conn: conn} do
      actual =
        conn
        |> get("/api/listAccessGroups?invalid_parameter=invalid")
        |> json_response(400)

      expected = %{"message" => "dataset_id, api_key, or user_id must be passed."}

      assert actual == expected
    end
  end
end

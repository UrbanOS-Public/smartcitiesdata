defmodule RaptorWeb.AuthorizeControllerTest do
  use RaptorWeb.ConnCase
  import Mox

  alias Raptor.Services.Auth0Management
  alias Raptor.Schemas.Auth0UserData
  alias Raptor.Services.DatasetStore
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.Services.DatasetAccessGroupRelationStore
  alias Raptor.Services.UserAccessGroupRelationStore

  # these simulate "raw json" attributes of an auth0 user
  #   available in the "Raw JSON" tab of a user's page
  @authorized_call [
    %Auth0UserData{
      email_verified: true,
      user_id: "penny",
      app_metadata: %{apiKey: "fakeApiKey"},
      blocked: false
    }
  ]

  @multiple_users_call [
    %Auth0UserData{
      email_verified: true
    },
    %Auth0UserData{
      email_verified: true
    }
  ]

  @unverified_email_call [
    %Auth0UserData{
      email_verified: false
    }
  ]

  @unauthorized_call []

  @blocked_user [
    %Auth0UserData{
      email_verified: true,
      blocked: true
    }
  ]

  setup :verify_on_exit!

  describe "private dataset authorization without api key" do
    test "returns true when the user has access to the given dataset via an organization", %{
      conn: conn
    } do
      system_name = "system__name"
      org_id = "dog_stats"
      user = @authorized_call |> List.first()
      user_id = user.user_id
      expected = %{"is_authorized" => true}

      expect(DatasetStoreMock, :get, fn system_name -> %{dataset_id: "wags", system_name: system_name, org_id: org_id, is_private: true} end)
      expect(UserOrgAssocStoreMock, :get, fn user_id, org_id -> %{user_id: user_id, org_id: org_id, email: "penny@starfleet.com"} end)

      actual =
        conn
        |> get("/api/authorize?auth0_user=#{user_id}&systemName=#{system_name}")
        |> json_response(200)

      assert actual == expected
    end

    test "returns true when the user has access to the given dataset via an access group", %{
      conn: conn
    } do
      system_name = "system__name"
      dataset_org_id = "dataset_org"
      dataset_id = "wags"
      user = @authorized_call |> List.first()
      user_id = user.user_id
      expected = %{"is_authorized" => true}

      expect(DatasetStoreMock, :get, fn system_name -> %{
          dataset_id: dataset_id,
          system_name: system_name,
          org_id: dataset_org_id,
          is_private: true
        } end)
      expect(UserOrgAssocStoreMock, :get, fn user_id, dataset_org_id -> %{} end)
      expect(UserAccessGroupRelationStoreMock, :get_all_by_user, fn user_id -> ["poodles", "german shepards", "sheepdog"] end)
      expect(DatasetAccessGroupRelationStoreMock, :get_all_by_dataset, fn dataset_id -> ["poodles", "golden retrievers", "labradoodles"] end)

      actual =
        conn
        |> get("/api/authorize?auth0_user=#{user_id}&systemName=#{system_name}")
        |> json_response(200)

      assert actual == expected
    end

    test "returns an error when the systemName is not passed", %{conn: conn} do
      expected = %{"message" => "systemName is a required parameter."}

      actual =
        conn
        |> get("/api/authorize?auth0_user=someUser")
        |> json_response(400)

      assert actual == expected
    end

    test "returns false when the dataset org does not match the user org or any access groups", %{
      conn: conn
    } do
      api_key = "enterprise"
      system_name = "system__name"
      dataset_org_id = "dataset_org"
      user = @authorized_call |> List.first()
      user_id = user.user_id
      expected = %{"is_authorized" => false}

      expect(DatasetStoreMock, :get, fn system_name -> %{
          dataset_id: "wags",
          system_name: system_name,
          org_id: dataset_org_id,
          is_private: true
        } end)
      expect(UserOrgAssocStoreMock, :get, fn user_id, dataset_org_id -> %{} end)
      expect(UserAccessGroupRelationStoreMock, :get_all_by_user, fn user_id -> [] end)
      expect(DatasetAccessGroupRelationStoreMock, :get_all_by_dataset, fn "wags" -> [] end)

      actual =
        conn
        |> get("/api/authorize?auth0_user=#{user_id}&systemName=#{system_name}")
        |> json_response(200)

      assert actual == expected
    end
  end

  describe "private dataset authorization" do
    test "returns true when there is one valid user that has the given api key", %{conn: conn} do
      api_key = "enterprise"
      system_name = "system__name"
      org_id = "dog_stats"
      user = @authorized_call |> List.first()
      user_id = user.user_id
      expected = %{"is_authorized" => true}
      expect(Auth0ManagementMock, :get_users_by_api_key, fn ^api_key -> {:ok, @authorized_call} end)
      expect(Auth0ManagementMock, :is_valid_user, fn _ -> true end)

      expect(DatasetStoreMock, :get, fn system_name -> %{dataset_id: "wags", system_name: system_name, org_id: org_id, is_private: true} end)
      expect(UserOrgAssocStoreMock, :get, fn user_id, org_id -> %{user_id: user_id, org_id: org_id, email: "penny@starfleet.com"} end)

      actual =
        conn
        |> get("/api/authorize?apiKey=#{api_key}&systemName=#{system_name}")
        |> json_response(200)

      assert actual == expected
    end

    test "returns false when the dataset org does not match the user org or any access groups", %{
      conn: conn
    } do
      api_key = "enterprise"
      system_name = "system__name"
      dataset_org_id = "dataset_org"
      user = @authorized_call |> List.first()
      user_id = user.user_id
      expected = %{"is_authorized" => false}
      expect(Auth0ManagementMock, :get_users_by_api_key, fn ^api_key -> {:ok, @authorized_call} end)
      expect(Auth0ManagementMock, :is_valid_user, fn _ -> true end)

      expect(DatasetStoreMock, :get, fn system_name -> %{
          dataset_id: "wags",
          system_name: system_name,
          org_id: dataset_org_id,
          is_private: true
        } end)
      expect(UserOrgAssocStoreMock, :get, fn user_id, dataset_org_id -> %{} end)
      expect(UserAccessGroupRelationStoreMock, :get_all_by_user, fn user_id -> [] end)
      expect(DatasetAccessGroupRelationStoreMock, :get_all_by_dataset, fn "wags" -> [] end)

      actual =
        conn
        |> get("/api/authorize?apiKey=#{api_key}&systemName=#{system_name}")
        |> json_response(200)

      assert actual == expected
    end

    test "returns true when the dataset org does not match the user org but there is a matching access group",
         %{conn: conn} do
      api_key = "enterprise"
      system_name = "system__name"
      dataset_org_id = "dataset_org"
      dataset_id = "wags"
      user = @authorized_call |> List.first()
      user_id = user.user_id
      expected = %{"is_authorized" => true}
      expect(Auth0ManagementMock, :get_users_by_api_key, fn ^api_key -> {:ok, @authorized_call} end)
      expect(Auth0ManagementMock, :is_valid_user, fn _ -> true end)

      expect(DatasetStoreMock, :get, fn system_name -> %{
          dataset_id: dataset_id,
          system_name: system_name,
          org_id: dataset_org_id,
          is_private: true
        } end)
      expect(UserOrgAssocStoreMock, :get, fn user_id, dataset_org_id -> %{} end)
      expect(UserAccessGroupRelationStoreMock, :get_all_by_user, fn user_id -> ["poodles", "german shepards", "sheepdog"] end)
      expect(DatasetAccessGroupRelationStoreMock, :get_all_by_dataset, fn dataset_id -> ["poodles", "golden retrievers", "labradoodles"] end)

      actual =
        conn
        |> get("/api/authorize?apiKey=#{api_key}&systemName=#{system_name}")
        |> json_response(200)

      assert actual == expected
    end

    test "returns false when the dataset org does not match the user org and there is not a matching access group",
         %{conn: conn} do
      api_key = "enterprise"
      system_name = "system__name"
      dataset_org_id = "dataset_org"
      dataset_id = "wags"
      user = @authorized_call |> List.first()
      user_id = user.user_id
      expected = %{"is_authorized" => false}
      expect(Auth0ManagementMock, :get_users_by_api_key, fn ^api_key -> {:ok, @authorized_call} end)
      expect(Auth0ManagementMock, :is_valid_user, fn _ -> true end)

      expect(DatasetStoreMock, :get, fn system_name -> %{
          dataset_id: dataset_id,
          system_name: system_name,
          org_id: dataset_org_id,
          is_private: true
        } end)
      expect(UserOrgAssocStoreMock, :get, fn user_id, dataset_org_id -> %{} end)
      expect(UserAccessGroupRelationStoreMock, :get_all_by_user, fn user_id -> ["german shepards", "sheepdog"] end)
      expect(DatasetAccessGroupRelationStoreMock, :get_all_by_dataset, fn dataset_id -> ["poodles", "golden retrievers", "labradoodles"] end)

      actual =
        conn
        |> get("/api/authorize?apiKey=#{api_key}&systemName=#{system_name}")
        |> json_response(200)

      assert actual == expected
    end

    test "returns false when the system name does not match an existing dataset", %{conn: conn} do
      api_key = "enterprise"
      system_name = "invalid_system__name"
      expected = %{"is_authorized" => false}

      expect(DatasetStoreMock, :get, fn system_name -> %{} end)

      actual =
        conn
        |> get("/api/authorize?apiKey=#{api_key}&systemName=#{system_name}")
        |> json_response(200)

      assert actual == expected
    end

    test "returns an error when the apiKey is not passed", %{conn: conn} do
      expected = %{"message" => "apiKey is a required parameter to access private datasets."}
      system_name = "some__data"

      expect(DatasetStoreMock, :get, fn system_name -> %{
          dataset_id: "wags",
          system_name: system_name,
          org_id: "dog_stats",
          is_private: true
        } end)

      actual =
        conn
        |> get("/api/authorize?systemName=#{system_name}")
        |> json_response(400)

      assert actual == expected
    end
  end

  describe "public dataset authorization" do
    test "always returns true", %{conn: conn} do
      system_name = "system__name"
      expected = %{"is_authorized" => true}

      expect(DatasetStoreMock, :get, fn system_name -> %{
          dataset_id: "wags",
          system_name: system_name,
          org_id: "dog_stats",
          is_private: false
        } end)

      actual =
        conn
        |> get("/api/authorize?systemName=#{system_name}")
        |> json_response(200)

      assert actual == expected
    end
  end

  describe "invalid input" do
    test "returns an error when the systemName is not passed", %{conn: conn} do
      expected = %{"message" => "systemName is a required parameter."}

      actual =
        conn
        |> get("/api/authorize?apiKey=apiKey")
        |> json_response(400)

      assert actual == expected
    end

    test "returns an error when the apiKey and the systemName are not passed", %{conn: conn} do
      expected = %{"message" => "systemName is a required parameter."}

      actual =
        conn
        |> get("/api/authorize")
        |> json_response(400)

      assert actual == expected
    end
  end

  describe "authentication" do
    test "returns false when there is one valid user that has the given api key but their email is not validated",
         %{conn: conn} do
      api_key = "enterprise"
      expected = %{"is_authorized" => false}

      expect(DatasetStoreMock, :get, fn _ -> %{
          dataset_id: "wags",
          system_name: "system__name",
          org_id: "dog_stats",
          is_private: true
        } end)
      expect(Auth0ManagementMock, :get_users_by_api_key, fn api_key -> {:ok, @unverified_email_call} end)
      expect(Auth0ManagementMock, :is_valid_user, fn _ -> false end)

      actual =
        conn
        |> get("/api/authorize?apiKey=#{api_key}&systemName=system__name")
        |> json_response(200)

      assert actual == expected
    end

    test "returns false when there is no valid user with the given api key", %{conn: conn} do
      api_key = "intrepid"
      expected = %{"is_authorized" => false}

      expect(DatasetStoreMock, :get, fn _ -> %{
          dataset_id: "wags",
          system_name: "system__name",
          org_id: "dog_stats",
          is_private: true
        } end)
      expect(Auth0ManagementMock, :get_users_by_api_key, fn api_key -> {:ok, @unauthorized_call} end)

      actual =
        conn
        |> get("/api/authorize?apiKey=#{api_key}&systemName=system__name")
        |> json_response(200)

      assert actual == expected
    end

    test "returns false when there are multiple users with the given api key", %{conn: conn} do
      api_key = "intrepid"
      expected = %{"is_authorized" => false}

      expect(DatasetStoreMock, :get, fn _ -> %{
          dataset_id: "wags",
          system_name: "system__name",
          org_id: "dog_stats",
          is_private: true
        } end)
      expect(Auth0ManagementMock, :get_users_by_api_key, fn api_key -> {:ok, @multiple_users_call} end)

      actual =
        conn
        |> get("/api/authorize?apiKey=#{api_key}&systemName=system__name")
        |> json_response(200)

      assert actual == expected
    end

    test "returns false when the api key matches a user but the user has been blocked", %{
      conn: conn
    } do
      api_key = "intrepid"
      expected = %{"is_authorized" => false}

      expect(DatasetStoreMock, :get, fn _ -> %{
          dataset_id: "wags",
          system_name: "system__name",
          org_id: "dog_stats",
          is_private: true
        } end)

      # mock that the user is in the org of the private dataset
      stub(UserOrgAssocStoreMock, :get, fn _, "dog_stats" -> %{"user|id|blah": true} end)

      expect(Auth0ManagementMock, :get_users_by_api_key, fn api_key -> {:ok, @blocked_user} end)
      expect(Auth0ManagementMock, :is_valid_user, fn _ -> false end)

      actual =
        conn
        |> get("/api/authorize?apiKey=#{api_key}&systemName=system__name")
        |> json_response(200)

      assert actual == expected
    end

    test "returns false if the auth0 management api returns an error", %{conn: conn} do
      api_key = "intrepid"
      expected = %{"is_authorized" => false}

      expect(DatasetStoreMock, :get, fn _ -> %{
          dataset_id: "wags",
          system_name: "system__name",
          org_id: "dog_stats",
          is_private: true
        } end)
      expect(Auth0ManagementMock, :get_users_by_api_key, fn ^api_key -> {:error, []} end)

      actual =
        conn
        |> get("/api/authorize?apiKey=#{api_key}&systemName=system__name")
        |> json_response(200)

      assert actual == expected
    end
  end
end

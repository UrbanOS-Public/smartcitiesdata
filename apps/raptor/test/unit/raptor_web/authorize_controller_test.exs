defmodule RaptorWeb.AuthorizeControllerTest do
  use RaptorWeb.ConnCase
  use Placebo
  alias Raptor.Services.Auth0Management
  alias Raptor.Services.DatasetStore
  alias Raptor.Services.UserOrgAssocStore

  @authorized_call [
    %{
      "email_verified" => true,
      "user_id" => "penny"
    }
  ]

  @multiple_users_call [
    %{
      "email_verified" => true
    },
    %{
      "email_verified" => true
    }
  ]

  @unverified_email_call [
    %{
      "email_verified" => false
    }
  ]

  @unauthorized_call []

  test "returns true when there is one valid user that has the given api key", %{conn: conn} do
    api_key = "enterprise"
    system_name = "system__name"
    org_id = "dog_stats"
    user = @authorized_call |> List.first()
    user_id = user["user_id"]
    expected = %{"is_authorized" => true}
    expect(Auth0Management.get_users_by_api_key(api_key), return: {:ok, @authorized_call})

    expect(DatasetStore.get(system_name),
      return: %{dataset_id: "wags", system_name: system_name, org_id: org_id}
    )

    expect(UserOrgAssocStore.get(user_id, org_id),
      return: %{user_id: user_id, org_id: org_id, email: "penny@starfleet.com"}
    )

    actual =
      conn
      |> get("/api/authorize?apiKey=#{api_key}&systemName=#{system_name}")
      |> json_response(200)

    assert actual == expected
  end

  test "returns false when the dataset org does not match the user org", %{conn: conn} do
      api_key = "enterprise"
      system_name = "system__name"
      dataset_org_id = "dataset_org"
      user = @authorized_call |> List.first()
      user_id = user["user_id"]
      expected = %{"is_authorized" => false}
      expect(Auth0Management.get_users_by_api_key(api_key), return: {:ok, @authorized_call})

      expect(DatasetStore.get(system_name),
        return: %{dataset_id: "wags", system_name: system_name, org_id: dataset_org_id}
      )

      expect(UserOrgAssocStore.get(user_id, dataset_org_id),
        return: %{}
      )

      actual =
        conn
        |> get("/api/authorize?apiKey=#{api_key}&systemName=#{system_name}")
        |> json_response(200)

      assert actual == expected
    end

    test "returns false when the system name does not match an existing dataset", %{conn: conn} do
      api_key = "enterprise"
      system_name = "invalid_system__name"
      user = @authorized_call |> List.first()
      user_id = user["user_id"]
      expected = %{"is_authorized" => false}
      expect(Auth0Management.get_users_by_api_key(api_key), return: {:ok, @authorized_call})

      expect(DatasetStore.get(system_name),
        return: %{}
      )

      actual =
        conn
        |> get("/api/authorize?apiKey=#{api_key}&systemName=#{system_name}")
        |> json_response(200)

      assert actual == expected
    end

  describe "authentication checks" do

    test "returns false when there is one valid user that has the given api key but their email is not validated",
         %{conn: conn} do
      api_key = "enterprise"
      expected = %{"is_authorized" => false}

      expect(Auth0Management.get_users_by_api_key(api_key),
        return: {:ok, @unverified_email_call}
      )

      actual = conn |> get("/api/authorize?apiKey=#{api_key}&systemName=system__name") |> json_response(200)

      assert actual == expected
    end

    test "returns false when there is no valid user with the given api key", %{conn: conn} do
      api_key = "intrepid"
      expected = %{"is_authorized" => false}

      expect(Auth0Management.get_users_by_api_key(api_key),
        return: {:ok, @unauthorized_call}
      )

      actual = conn |> get("/api/authorize?apiKey=#{api_key}&systemName=system__name") |> json_response(200)

      assert actual == expected
    end

    test "returns false when there are multiple users with the given api key", %{conn: conn} do
      api_key = "intrepid"
      expected = %{"is_authorized" => false}

      expect(Auth0Management.get_users_by_api_key(api_key),
        return: {:ok, @multiple_users_call}
      )

      actual = conn |> get("/api/authorize?apiKey=#{api_key}&systemName=system__name") |> json_response(200)

      assert actual == expected
    end

    test "returns false if the auth0 management api returns an error", %{conn: conn} do
      api_key = "intrepid"
      expected = %{"is_authorized" => false}
      expect(Auth0Management.get_users_by_api_key(api_key), return: {:error, []})
      actual = conn |> get("/api/authorize?apiKey=#{api_key}&systemName=system__name") |> json_response(200)

      assert actual == expected
    end
  end
end

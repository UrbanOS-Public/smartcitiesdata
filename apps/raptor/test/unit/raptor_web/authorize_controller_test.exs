defmodule RaptorWeb.AuthorizeControllerTest do
  use RaptorWeb.ConnCase
  use Placebo
  alias Raptor.Services.Auth0Management

  @authorized_call [
    %{
      "email_verified" => true
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

  describe "authorize controller" do
    test "returns true when there is one valid user that has the given api key", %{conn: conn} do
      api_key = "enterprise"
      expected = %{"is_authorized" => true}
      expect(Auth0Management.get_users_by_api_key(api_key), return: {:ok, @authorized_call})
      actual = conn |> get("/api/authorize?apiKey=#{api_key}") |> json_response(200)

      assert actual == expected
    end

    test "returns false when there is one valid user that has the given api key but their email is not validated",
         %{conn: conn} do
      api_key = "enterprise"
      expected = %{"is_authorized" => false}

      expect(Auth0Management.get_users_by_api_key(api_key),
        return: {:ok, @unverified_email_call}
      )

      actual = conn |> get("/api/authorize?apiKey=#{api_key}") |> json_response(200)

      assert actual == expected
    end

    test "returns false when there is no valid user with the given api key", %{conn: conn} do
      api_key = "intrepid"
      expected = %{"is_authorized" => false}

      expect(Auth0Management.get_users_by_api_key(api_key),
        return: {:ok, @unauthorized_call}
      )

      actual = conn |> get("/api/authorize?apiKey=#{api_key}") |> json_response(200)

      assert actual == expected
    end

    test "returns false when there are multiple users with the given api key", %{conn: conn} do
      api_key = "intrepid"
      expected = %{"is_authorized" => false}

      expect(Auth0Management.get_users_by_api_key(api_key),
        return: {:ok, @multiple_users_call}
      )

      actual = conn |> get("/api/authorize?apiKey=#{api_key}") |> json_response(200)

      assert actual == expected
    end

    test "returns false if the auth0 management api returns an error", %{conn: conn} do
      api_key = "intrepid"
      expected = %{"is_authorized" => false}
      expect(Auth0Management.get_users_by_api_key(api_key), return: {:error, []})
      actual = conn |> get("/api/authorize?apiKey=#{api_key}") |> json_response(200)

      assert actual == expected
    end
  end
end

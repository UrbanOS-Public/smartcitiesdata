defmodule DiscoveryApiWeb.UserControllerTest do
  use DiscoveryApiWeb.Test.AuthConnCase.UnitCase
  use Placebo

  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Services.AuthService

  @instance_name DiscoveryApi.instance_name()

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()
    auth_conn_case.disable_user_addition.()
    :ok
  end

  describe "POST /logged-in" do
    test "returns 200 when no errors", %{authorized_conn: conn} do
      expect(AuthService.create_logged_in_user(any()), return: {:ok, conn})

      response_body = conn
      |> post("/api/v1/logged-in")
      |> response(200)

      response_body == ""
    end

    test "returns 500 Internal Server Error create call fails", %{authorized_conn: conn} do
      expect(AuthService.create_logged_in_user(any()), return: {:error, "error"})

      response_body = conn
                      |> post("/api/v1/logged-in")
                      |> response(500)

      response_body == "Internal Server Error"
    end
  end
end

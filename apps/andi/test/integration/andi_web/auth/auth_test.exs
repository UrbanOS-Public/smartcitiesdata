defmodule AndiWeb.AuthTest do
  @moduledoc false
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  import AndiWeb.Test.PublicAccessCase

  describe "required login" do
    test "redirects users who are not authenticated to login page" do
      unauthenticated_conn = build_conn()
      result = get(unauthenticated_conn, "/datasets")

      assert result.status == 302
      assert result.resp_body =~ "/auth/auth0?prompt=login\""
    end

    test "redirects users not assigned to proper role back to login page with error message", %{unauthorized_conn: conn} do
      result = get(conn, "/organizations")

      assert result.status == 302
      assert result.resp_body =~ "error_message=Unauthorized\""
    end

    test "returns 200 when user is authenticated and has correct roles", %{curator_conn: conn} do
      result = get(conn, "/datasets")

      assert result.status == 200
    end
  end

  describe "public mode" do
    setup do
      on_exit(set_access_level(:public))
      restart_andi()

      Ecto.Adapters.SQL.Sandbox.checkout(Andi.Repo)
      Ecto.Adapters.SQL.Sandbox.mode(Andi.Repo, {:shared, self()})

      :ok
    end

    test "redirects users who are not authenticated to login page" do
      unauthenticated_conn = build_conn()
      result = get(unauthenticated_conn, "/datasets")

      assert result.status == 302
      assert result.resp_body =~ "/auth/auth0?prompt=login\""
    end

    test "returns 200 when user is authenticated and has correct roles", %{curator_conn: conn} do
      result = get(conn, "/datasets")

      assert result.status == 200
    end
  end

  describe "logout" do
    test "revokes token so it cannot be used again", %{revocable_conn: conn} do
      result = get(conn, "/auth/auth0/logout")

      auth0_issuer =
        Application.get_env(:andi, AndiWeb.Auth.TokenHandler)
        |> Keyword.get(:issuer)

      auth0_log_out_url = auth0_issuer <> "v2/logout"

      assert result.status == 302
      assert result.resp_body =~ auth0_log_out_url

      result = get(conn, "/datasets")
      assert result.status == 302
      assert result.resp_body =~ "/auth/auth0?prompt=login\""
    end

    test "puts the correct return url in the logout request to auth0", %{revocable_conn: conn} do
      result = get(conn, "/auth/auth0/logout")

      assert result.status == 302
      assert result.resp_body =~ "returnTo=http://www.example.com/auth/auth0&"
    end

    test "does not affect other, curator-tier users", %{revocable_conn: conn, curator_conn: curator_conn} do
      result = get(conn, "/auth/auth0/logout")

      assert result.status == 302
      assert result.resp_body =~ "v2/logout"

      assert get(curator_conn, "/datasets")
             |> response(200)
    end

    test "does not affect other, public-tier users", %{revocable_conn: conn, public_conn: public_conn} do
      result = get(conn, "/auth/auth0/logout")

      assert result.status == 302
      assert result.resp_body =~ "v2/logout"

      assert get(public_conn, "/datasets")
             |> response(200)
    end
  end
end

defmodule AndiWeb.AuthTest do
  @moduledoc false
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

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

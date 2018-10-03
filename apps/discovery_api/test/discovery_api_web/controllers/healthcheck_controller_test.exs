defmodule DiscoveryApiWeb.HealthcheckControllerTest do
  use DiscoveryApiWeb.ConnCase

  test "GET /healthcheck", %{conn: conn} do
    conn = get conn, "/healthcheck"
    assert text_response(conn, 200) =~ "Hello, React!"
  end
end

defmodule EstuaryWeb.HealthcheckControllerTest do
  use EstuaryWeb.ConnCase

  @tag capture_log: true
  test "GET /healthcheck/", %{conn: conn} do
    conn = get(conn, "/healthcheck")
    assert text_response(conn, 200) =~ "Up"
  end
end

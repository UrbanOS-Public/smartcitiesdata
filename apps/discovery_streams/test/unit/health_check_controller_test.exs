defmodule CotaStreamingConsumerWeb.HealthCheckControllerTest do
  use CotaStreamingConsumerWeb.ConnCase

  test "GET /socket/healthcheck", %{conn: conn} do
    conn = get(conn, "/socket/healthcheck")
    assert text_response(conn, 200) =~ "Up"
  end
end

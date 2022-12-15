defmodule DiscoveryApiWeb.Plugs.RequireApiKeyTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  alias DiscoveryApiWeb.Plugs.RequireApiKey

  alias RaptorService

  describe "call/1" do
    test "responds with a 401 when require_api_key env var is true and user does not pass api_key" do
      allow(DiscoveryApiWeb.RenderError.render_error(any(), any(), any()), exec: fn conn, _, _ -> conn end)
      conn = build_conn(:get, "/doesnt/matter")
      result = RequireApiKey.call(conn)

      assert_called(DiscoveryApiWeb.RenderError.render_error(conn, 401, "Unauthorized: required header api_key not present"))
      assert result.halted == true
    end

    test "responds with a 401 when require_api_key env var is true and user passes invalid api_key" do
      allow(RaptorService.is_valid_api_key(any(), any()), return: false)
      allow(DiscoveryApiWeb.RenderError.render_error(any(), any(), any()), exec: fn conn, _, _ -> conn end)

      conn =
        build_conn(:get, "/doesnt/matter")
        |> put_req_header("api_key", "invalidApiKey")

      result = RequireApiKey.call(conn)

      assert_called(DiscoveryApiWeb.RenderError.render_error(conn, 401, "Unauthorized: invalid api_key"))
      assert result.halted == true
    end

    test "responds with a 200 when require_api_key env var is true and user passes valid api_key" do
      allow(RaptorService.is_valid_api_key(any(), any()), return: true)

      conn =
        build_conn(:get, "/doesnt/matter")
        |> put_req_header("api_key", "validApiKey")

      result = RequireApiKey.call(conn)

      assert result == conn
    end
  end
end

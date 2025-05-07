defmodule AndiWeb.Plugs.APIRequireCuratorTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Phoenix.ConnTest
  import Mock

  alias AndiWeb.Plugs.APIRequireCurator

  describe "call/1 REQUIRE_ADMIN_API_KEY false" do
    test "Passes the connection through when REQUIRE_ADMIN_API_KEY is not required" do
      System.put_env("REQUIRE_ADMIN_API_KEY", "false")
      conn = build_conn(:get, "/doesnt/matter")
      result = APIRequireCurator.call(conn, [])

      assert result.resp_body == nil
    end
  end

  describe "call/1 REQUIRE_ADMIN_API_KEY true" do
    setup do
      on_exit(fn -> System.put_env("REQUIRE_ADMIN_API_KEY", "false") end)
      System.put_env("REQUIRE_ADMIN_API_KEY", "true")

      :ok
    end

    test "responds with a 401 when user does not pass api_key" do
      conn = build_conn(:get, "/doesnt/matter")
      result = APIRequireCurator.call(conn, [])

      result.resp_body == "Unauthorized: required header api_key not present"
    end

    test "returns connection when Raptor service validates the auth0 role" do
      with_mock(RaptorService, check_auth0_role: fn _, _, _ -> {:ok, "\"has_role\": true"} end) do
        conn = build_conn(:get, "/doesnt/matter")
        result = APIRequireCurator.call(conn, [])

        result.resp_body == nil
      end
    end

    test "returns invalid api key response when Raptor cannot validate api key" do
      with_mock(RaptorService, check_auth0_role: fn _, _, _ -> {:ok, "\"has_role\": false"} end) do
        conn = build_conn(:get, "/doesnt/matter")
        result = APIRequireCurator.call(conn, [])

        result.resp_body == "Unauthorized: Missing user role"
      end
    end

    test "returns internal error when Raptor has internal error" do
      with_mock(RaptorService, check_auth0_role: fn _, _, _ -> {:error, "doesntMatter", 500} end) do
        conn = build_conn(:get, "/doesnt/matter")
        result = APIRequireCurator.call(conn, [])

        result.resp_body == "Internal Server Error"
      end
    end
  end

  defp get(path, router) do
    router_opts = router.init([])

    :get
    |> conn(path)
    |> router.call(router_opts)
  end
end

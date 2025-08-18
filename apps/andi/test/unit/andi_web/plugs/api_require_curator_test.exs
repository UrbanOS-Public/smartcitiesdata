defmodule AndiWeb.Plugs.APIRequireCuratorTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Phoenix.ConnTest

  alias AndiWeb.Plugs.APIRequireCurator

  @moduletag timeout: 5000

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
      on_exit(fn -> 
        System.put_env("REQUIRE_ADMIN_API_KEY", "false")
        # Clean up :meck if it was used
        try do
          :meck.unload(RaptorService)
        catch
          _, _ -> :ok
        end
      end)
      System.put_env("REQUIRE_ADMIN_API_KEY", "true")

      :ok
    end

    test "responds with a 401 when user does not pass api_key" do
      conn = build_conn(:get, "/doesnt/matter")
      result = APIRequireCurator.call(conn, [])

      assert result.resp_body == "Unauthorized: Invalid header api_key"
    end

    test "returns connection when Raptor service validates the auth0 role" do
      # Set up :meck for RaptorService
      try do
        :meck.new(RaptorService, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(RaptorService, :check_auth0_role, fn _, _, _ -> {:ok, true} end)
      
      conn = build_conn(:get, "/doesnt/matter")
             |> put_req_header("api_key", "valid_api_key")
      result = APIRequireCurator.call(conn, [])

      assert result.resp_body == nil
    end

    test "returns invalid api key response when Raptor cannot validate api key" do
      # Set up :meck for RaptorService
      try do
        :meck.new(RaptorService, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(RaptorService, :check_auth0_role, fn _, _, _ -> {:ok, false} end)
      
      conn = build_conn(:get, "/doesnt/matter")
             |> put_req_header("api_key", "invalid_api_key")
      result = APIRequireCurator.call(conn, [])

      assert result.resp_body == "Unauthorized: Missing user role"
    end

    test "returns internal error when Raptor has internal error" do
      # Set up :meck for RaptorService
      try do
        :meck.new(RaptorService, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
      
      :meck.expect(RaptorService, :check_auth0_role, fn _, _, _ -> {:error, "doesntMatter", 500} end)
      
      conn = build_conn(:get, "/doesnt/matter")
             |> put_req_header("api_key", "some_api_key")
      result = APIRequireCurator.call(conn, [])

      assert result.resp_body == "Internal Server Error"
    end
  end

  defp get(path, router) do
    router_opts = router.init([])

    :get
    |> conn(path)
    |> router.call(router_opts)
  end
end

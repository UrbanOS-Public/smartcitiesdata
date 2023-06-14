defmodule AndiWeb.Auth.EnsureAccessLevelForRouteTest do
  use ExUnit.Case
  use AndiWeb.ConnCase

  import AndiWeb.Test.PublicAccessCase
  import Mock

  alias AndiWeb.Auth.EnsureAccessLevelForRoute

  setup do
    on_exit(set_access_level(:private))
  end

  describe "init/1" do
    test "requires a :router setting" do
      assert_raise RuntimeError, fn ->
        EnsureAccessLevelForRoute.init([])
      end
    end
  end

  describe "call/2" do
    test "returns a 404 for a controller that does not provide access level config" do
      conn =
        build_conn(:get, "/unspecified")
        |> EnsureAccessLevelForRoute.call(router: AndiWeb.Test.Router)

      assert conn.status == 404
      assert conn.halted
    end

    test "returns a 404 for a controller that provides non-matching access level config" do
      conn =
        build_conn(:get, "/no-match")
        |> EnsureAccessLevelForRoute.call(router: AndiWeb.Test.Router)

      assert conn.status == 404
      assert conn.halted
    end

    test "passes through for a provided, matching access level" do
      conn =
        build_conn(:get, "/match")
        |> EnsureAccessLevelForRoute.call(router: AndiWeb.Test.Router)

      refute conn.status == 404
      refute conn.halted
    end

    test "returns a 404 for a controller-less live view that does not provide access level config" do
      conn =
        build_conn(:get, "/live-unspecified")
        |> EnsureAccessLevelForRoute.call(router: AndiWeb.Test.Router)

      assert conn.status == 404
      assert conn.halted
    end

    test "returns a 404 for a provided, non-matching, controller-less live view" do
      conn =
        build_conn(:get, "/live-no-match")
        |> EnsureAccessLevelForRoute.call(router: AndiWeb.Test.Router)

      assert conn.status == 404
      assert conn.halted
    end

    test "passes through for a provided, matching, controller-less live view" do
      conn =
        build_conn(:get, "/live-match")
        |> EnsureAccessLevelForRoute.call(router: AndiWeb.Test.Router)

      refute conn.status == 404
      refute conn.halted
    end

    test "plugs can be excluded" do
      conn =
        build_conn(:get, "/excluded")
        |> EnsureAccessLevelForRoute.call(router: AndiWeb.Test.Router, exclusions: [AndiWeb.Test.ExcludeMe, AndiWeb.Test.ExcludeMeToo])

      refute conn.status == 404
      refute conn.halted
    end

    test "live views can be excluded" do
      conn =
        build_conn(:get, "/live-excluded")
        |> EnsureAccessLevelForRoute.call(
          router: AndiWeb.Test.Router,
          exclusions: [AndiWeb.Test.ExcludedLiveView, AndiWeb.Test.ExcludeMeToo]
        )

      refute conn.status == 404
      refute conn.halted
    end

    test "controllers can be excluded" do
      conn =
        build_conn(:get, "/controller-excluded")
        |> EnsureAccessLevelForRoute.call(
          router: AndiWeb.Test.Router,
          exclusions: [AndiWeb.Test.ExcludedController, AndiWeb.Test.ExcludeMeToo]
        )

      refute conn.status == 404
      refute conn.halted
    end

    test "accurately returns a 404" do
      conn =
        build_conn(:get, "/NOT-FOUND!!!")
        |> EnsureAccessLevelForRoute.call(router: AndiWeb.Test.Router)

      assert conn.status == 404
      assert conn.halted
    end

    test "if an exception occurs, returns 404, not 500" do
      with_mock(AndiWeb.Test.FailingController, [access_levels_supported: fn(_) -> raise "KABOOM!" end]) do
        conn =
          build_conn(:get, "/kaboom")
          |> EnsureAccessLevelForRoute.call(router: AndiWeb.Test.Router)

        assert conn.status == 404
        assert conn.halted
      end
    end
  end
end

defmodule AndiWeb.Test.UnspecifiedController do
  use AndiWeb, :controller

  def unspecified(conn, _params) do
    resp(conn, 200, "data exposed!")
  end
end

defmodule AndiWeb.Test.UnspecifiedLiveView do
  use AndiWeb, :live_view

  def render(assigns) do
    ~L"""
    Exposed data!
    """
  end
end

defmodule AndiWeb.Test.SpecifiedController do
  use AndiWeb, :controller

  access_levels(
    no_match: [:public],
    match: [:public, :private]
  )

  def no_match(conn, _params) do
    resp(conn, 200, "data exposed!")
  end

  def match(conn, _params) do
    resp(conn, 200, "data exposed!")
  end
end

defmodule AndiWeb.Test.FailingController do
  use AndiWeb, :controller

  access_levels(kaboom: [:public])

  def kaboom(conn, _params) do
    resp(conn, 200, "kaboom")
  end
end

defmodule AndiWeb.Test.SpecifiedNonMatchingLiveView do
  use AndiWeb, :live_view

  access_levels(render: [:public])

  def render(assigns) do
    ~L"""
    Exposed data!
    """
  end
end

defmodule AndiWeb.Test.SpecifiedMatchingLiveView do
  use AndiWeb, :live_view

  access_levels(render: [:public, :private])

  def render(assigns) do
    ~L"""
    Exposed data!
    """
  end
end

defmodule AndiWeb.Test.ExcludedMe do
  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    conn
  end
end

defmodule AndiWeb.Test.ExcludedController do
  use AndiWeb, :controller

  def excluded(_conn, _params) do
    "does not matter"
  end
end

defmodule AndiWeb.Test.ExcludedLiveView do
  use AndiWeb, :live_view

  def render(assigns) do
    ~L"""
    Good times!
    """
  end
end

defmodule AndiWeb.Test.Router do
  use AndiWeb, :router

  scope "/" do
    get "/unspecified", AndiWeb.Test.UnspecifiedController, :unspecified
    get "/no-match", AndiWeb.Test.SpecifiedController, :no_match
    get "/match", AndiWeb.Test.SpecifiedController, :match

    live "/live-unspecified", AndiWeb.Test.UnspecifiedLiveView, layout: {AndiWeb.LayoutView, :app}
    live "/live-no-match", AndiWeb.Test.SpecifiedNonMatchingLiveView, layout: {AndiWeb.LayoutView, :app}
    live "/live-match", AndiWeb.Test.SpecifiedMatchingLiveView, layout: {AndiWeb.LayoutView, :app}

    get "/excluded", AndiWeb.Test.ExcludeMe, match: "me"
    get "/controller-excluded", AndiWeb.Test.ExcludedController, :excluded
    live "/live-excluded", AndiWeb.Test.ExcludedLiveView, layout: {AndiWeb.LayoutView, :app}

    get "/kaboom", AndiWeb.Test.FailingController, :kaboom
  end
end

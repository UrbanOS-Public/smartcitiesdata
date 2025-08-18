defmodule AndiWeb.RedirectTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias AndiWeb.Redirect

  @moduletag timeout: 5000

  defmodule TestRouter do
    use Phoenix.Router

    get "/somewhere", Redirect, to: "/somewhere_else"

    get "/bad_opts", Redirect, []
  end

  test "redirects to another route" do
    response = get("/somewhere", TestRouter)

    assert response.status == 302
    assert String.contains?(response.resp_body, ~s|href="/somewhere_else"|)
  end

  test "raises an exception if no 'to' is defined" do
    assert_raise Plug.Conn.WrapperError, ~R|Missing.*:to|, fn ->
      get("/bad_opts", TestRouter)
    end
  end

  defp get(path, router) do
    router_opts = router.init([])

    :get
    |> conn(path)
    |> router.call(router_opts)
  end
end

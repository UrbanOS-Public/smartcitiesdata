defmodule DiscoveryApiWeb.LoginControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias Plug.Conn

  describe "GET /login" do
    setup do
      allow(Paddle.authenticate("bob", "12345"), return: :ok)
      allow(Paddle.authenticate(nil, nil), return: {:error, :invalidCredentials})

      conn =
        build_conn()
        |> Conn.put_req_header("authorization", "Basic " <> Base.encode64("bob:12345"))
        |> get("/api/v1/login")

      conn |> response(200)

      {:ok, %{response_conn: conn}}
    end

    test "sets cookie as httponly", %{response_conn: conn} do
      cookie = conn |> Helper.extract_response_cookie_as_map()

      assert Map.get(cookie, "HttpOnly") == true
    end

    test "sets cookie as secure", %{response_conn: conn} do
      cookie = conn |> Helper.extract_response_cookie_as_map()

      assert Map.get(cookie, "secure") == true
    end
  end

  test "GET /login fails", %{conn: conn} do
    allow(Paddle.authenticate(any(), any()), return: {:error, :invalidCredentials})

    conn
    |> Conn.put_req_header("authorization", "Basic " <> Base.encode64("bob:12345"))
    |> get("/api/v1/login")
    |> response(401)
  end
end

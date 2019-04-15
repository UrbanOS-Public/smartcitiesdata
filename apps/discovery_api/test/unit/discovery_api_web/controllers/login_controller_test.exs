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

    test "returns cookie with httponly", %{response_conn: conn} do
      cookie = conn |> Helper.extract_response_cookie_as_map()

      assert Map.get(cookie, "HttpOnly") == true
    end

    test "returns cookie with secure", %{response_conn: conn} do
      cookie = conn |> Helper.extract_response_cookie_as_map()

      assert Map.get(cookie, "secure") == true
    end

    test "returns cookie token with type 'refresh'", %{response_conn: conn} do
      cookie = conn |> Helper.extract_response_cookie_as_map()

      {:ok, token} =
        cookie
        |> Map.get(Helper.default_guardian_token_key())
        |> DiscoveryApi.Auth.Guardian.decode_and_verify()

      assert Map.get(token, "typ") == "refresh"
    end

    test "returns token header with type 'access'", %{response_conn: conn} do
      {:ok, token} =
        conn
        |> Conn.get_resp_header("token")
        |> List.first()
        |> DiscoveryApi.Auth.Guardian.decode_and_verify()

      assert Map.get(token, "typ") == "access"
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

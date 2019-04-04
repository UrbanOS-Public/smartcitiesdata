defmodule DiscoveryApiWeb.LoginControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias Plug.Conn

  test "GET /login", %{conn: conn} do
    allow(Paddle.authenticate("bob", "12345"), return: :ok)
    allow(Paddle.authenticate(nil, nil), return: {:error, :invalidCredentials})

    conn =
      conn
      |> Conn.put_req_header("authorization", "Basic " <> Base.encode64("bob:12345"))
      |> get("/api/v1/login")

    conn |> response(200)
    refute is_nil(Conn.get_resp_header(conn, "token"))
  end

  test "GET /login fails", %{conn: conn} do
    allow(Paddle.authenticate(any(), any()), return: {:error, :invalidCredentials})

    conn
    |> Conn.put_req_header("authorization", "Basic " <> Base.encode64("bob:12345"))
    |> get("/api/v1/login")
    |> response(401)
  end
end

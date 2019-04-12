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
      cookie = conn |> extract_session_cookie_as_map()

      assert Map.get(cookie, "HttpOnly") == true
    end

    test "sets cookie as secure", %{response_conn: conn} do
      cookie = conn |> extract_session_cookie_as_map()

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

  defp extract_session_cookie_as_map(conn) do
    conn
    |> Conn.get_resp_header("set-cookie")
    |> List.first()
    |> String.split("; ")
    |> Enum.map(&String.split(&1, "="))
    |> Enum.reduce(%{}, fn key_value, acc -> Map.put(acc, Enum.at(key_value, 0), Enum.at(key_value, 1, true)) end)
  end
end

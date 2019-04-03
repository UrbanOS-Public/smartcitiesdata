defmodule DiscoveryApiWeb.LoginController do
  require Logger
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Auth.Guardian

  def new(conn, _) do
    {user, password} = extract_auth(conn)

    with :ok <- Paddle.authenticate(user, password) do
      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      conn
      |> Plug.Conn.put_resp_header("token", token)
      |> text("#{user} logged in.")
    else
      {:error, :invalidCredentials} -> render_error(conn, 401, "Not Authorized")
    end
  end

  def extract_auth(conn) do
    conn
    |> Plug.Conn.get_req_header("authorization")
    |> List.last()
    |> String.split(" ")
    |> List.last()
    |> Base.decode64!()
    |> String.split(":")
    |> List.to_tuple()
  end
end

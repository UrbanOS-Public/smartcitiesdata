defmodule DiscoveryApiWeb.LoginController do
  require Logger
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Auth.Guardian

  def login(conn, _) do
    {user, password} = extract_auth(conn)

    case PaddleWrapper.authenticate(user, password) do
      :ok ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)

        conn
        |> Plug.Conn.put_resp_header("token", token)
        |> Guardian.Plug.sign_in(user)
        |> Guardian.Plug.remember_me(user)
        |> text("#{user} logged in.")

      {:error, :invalidCredentials} ->
        render_error(conn, 401, "Not Authorized")
    end
  end

  def logout(conn, _) do
    jwt = extract_token(conn)

    case Guardian.revoke(jwt) do
      {:ok, _claims} ->
        conn
        |> Guardian.Plug.sign_out(clear_remember_me: true)
        |> text("Logged out.")

      {:error, _error} ->
        render_error(conn, 404, "Not Found")
    end
  end

  defp extract_auth(conn) do
    conn
    |> Plug.Conn.get_req_header("authorization")
    |> List.last()
    |> String.split(" ")
    |> List.last()
    |> Base.decode64!()
    |> String.split(":")
    |> List.to_tuple()
  end

  defp extract_token(conn) do
    conn
    |> Plug.Conn.get_req_header("authorization")
    |> List.last()
    |> String.split(" ")
    |> List.last()
  end
end

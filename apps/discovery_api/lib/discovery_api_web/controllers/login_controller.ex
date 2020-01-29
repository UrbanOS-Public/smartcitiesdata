defmodule DiscoveryApiWeb.LoginController do
  require Logger
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Auth.Guardian
  alias DiscoveryApi.Schemas.Users

  def login(conn, _) do
    {username, password} = extract_auth(conn)

    case PaddleWrapper.authenticate(username, password) do
      :ok ->
        Users.create_or_update(username, %{email: get_email(username)})
        {:ok, token, _claims} = Guardian.encode_and_sign(username)

        conn
        |> Plug.Conn.put_resp_header("token", token)
        |> Guardian.Plug.sign_in(username)
        |> Guardian.Plug.remember_me(username)
        |> text("#{username} logged in.")

      {:error, :invalidCredentials} ->
        render_error(conn, 401, "Not Authorized")
    end
  end

  def logout(conn, _) do
    jwt = Guardian.Plug.current_token(conn)

    case Guardian.revoke(jwt) do
      {:ok, _claims} ->
        conn
        |> Guardian.Plug.sign_out(clear_remember_me: true)
        |> text("Logged out.")

      {:error, _error} ->
        render_error(conn, 404, "Not Found")
    end
  end

  defp get_email(username) do
    with {:ok, results} <- PaddleWrapper.get(filter: [uid: username]),
         email <- get_first_email_from_ldap_entries(results),
         false <- email == nil do
      email
    else
      error ->
        Logger.warn("Unable to retrieve email for from LDAP for #{username}, error: #{inspect(error)}")
        "N/A"
    end
  end

  defp get_first_email_from_ldap_entries(entries) do
    entries
    |> Enum.find(%{}, fn entry ->
      Map.get(entry, "mail", []) |> length() > 0
    end)
    |> Map.get("mail", [])
    |> List.first()
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
end

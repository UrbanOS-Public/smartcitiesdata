defmodule DiscoveryApi.Auth.Guardian do
  @moduledoc false
  use Guardian, otp_app: :discovery_api
  require Logger

  def subject_for_token(resource, _claims) do
    {:ok, resource}
  end

  def resource_from_claims(claims) do
    id = claims["sub"]
    user = Application.get_env(:discovery_api, :ldap_user)
    pass = Application.get_env(:discovery_api, :ldap_pass)
    Paddle.authenticate(user, pass)
    sub_dn = Paddle.config(:account_subdn)

    with {:ok, resources} <- Paddle.get(base: "uid=#{id},#{sub_dn}") do
      {:ok, List.first(resources)}
    else
      error ->
        Logger.error(inspect(error))
        error
    end
  end

  def current_claims(conn) do
    token = Plug.Conn.get_req_header(conn, "token")
    {:ok, claims} = DiscoveryApi.Auth.Guardian.decode_and_verify(token)
    List.first(claims)
  end
end

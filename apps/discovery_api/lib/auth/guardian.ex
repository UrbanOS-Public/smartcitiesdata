defmodule DiscoveryApi.Auth.Guardian do
  @moduledoc false
  use Guardian, otp_app: :discovery_api

  def subject_for_token(resource, _claims) do
    {:ok, resource}
  end

  def resource_from_claims(claims) do
    id = claims["sub"]
    {:ok, resources} = Paddle.get(filter: [uid: id])
    {:ok, List.first(resources)}
  end

  def current_claims(conn) do
    token = Plug.Conn.get_req_header(conn, "token")
    {:ok, claims} = DiscoveryApi.Auth.Guardian.decode_and_verify(token)
    List.first(claims)
  end
end

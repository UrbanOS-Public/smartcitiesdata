defmodule DiscoveryApi.Auth.Guardian do
  @moduledoc false
  use Guardian, otp_app: :discovery_api

  def subject_for_token(resource, _claims) do
    {:ok, resource}
  end

  def resource_from_claims(claims) do
    id = claims["sub"]
    resource = Paddle.get(filter: [uid: id])
    {:ok, resource}
  end
end

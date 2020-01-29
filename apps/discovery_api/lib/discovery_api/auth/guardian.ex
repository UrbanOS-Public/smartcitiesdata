defmodule DiscoveryApi.Auth.Guardian do
  @moduledoc false
  use Guardian, otp_app: :discovery_api, cookie_options: [secure: true, http_only: true]
  require Logger

  alias DiscoveryApi.Schemas.Users

  def subject_for_token(resource, _claims) do
    {:ok, resource}
  end

  def resource_from_claims(claims) do
    Users.get_user_with_organizations(claims["sub"], :subject_id)
  end
end

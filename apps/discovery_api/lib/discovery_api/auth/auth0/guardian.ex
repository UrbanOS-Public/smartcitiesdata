defmodule DiscoveryApi.Auth.Auth0.Guardian do
  @moduledoc false
  use Guardian, otp_app: :discovery_api

  def subject_for_token(resource, _claims) do
    {:ok, resource}
  end

  def resource_from_claims(claims) do
    {:ok, claims}
  end
end

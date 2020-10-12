defmodule DiscoveryApiWeb.Auth.TokenHandler do
  @moduledoc """
  A module that hooks into Guardian's token lifecycle in order to provide extra verifications.
  Primarily, this module introduces Guardian.DB for token revocation purposes.

  Major differences with usual Guardian.DB implementation:
  - we don't generate the token in the API
  - we only track revoked tokes, not ALL tokens
  - verification in this case checks if the token has been revoked, not that it exists in the DB
  """

  use Guardian, otp_app: :discovery_api, secret_fetcher: Auth.Auth0.SecretFetcher
  use Auth.TokenHandler

  alias DiscoveryApi.Schemas.Users
  require Logger

  def subject_for_token(resource, _claims) do
    {:ok, resource}
  end

  def resource_from_claims(claims) do
    Users.get_user_with_organizations(claims["sub"], :subject_id)
  end
end

defmodule DiscoveryApiWeb.Auth.TokenHandler do
  @moduledoc """
  Token handling specific to Discovery API.
  """

  use Auth.Guardian.TokenHandler,
    otp_app: :discovery_api

  alias DiscoveryApi.Schemas.Users

  @doc """
  Determines the subject for a token based on a resource that was previously loaded and the actual token claims.
  """
  def subject_for_token(resource, _claims) do
    {:ok, resource}
  end

  @doc """
  Given the claims loads a resource (user or otherwise) from a database or separate service to fill out the resource details, such as email, name, etc.
  """
  def resource_from_claims(claims) do
    Users.get_user_with_organizations(claims["sub"], :subject_id)
  end
end

defmodule DiscoveryApi.Services.AuthService do
  @moduledoc """
  Interface for calling remote services for auth.
  """

  def get_user_info(token) do
    case HTTPoison.get(user_info_endpoint(), [{"Authorization", "Bearer #{token}"}]) do
      {:ok, response} -> Jason.decode(response.body)
      error -> error
    end
  end

  defp user_info_endpoint() do
    issuer =
      Application.get_env(:discovery_api, DiscoveryApiWeb.Auth.TokenHandler)
      |> Keyword.fetch!(:issuer)

    issuer <> "userinfo"
  end
end

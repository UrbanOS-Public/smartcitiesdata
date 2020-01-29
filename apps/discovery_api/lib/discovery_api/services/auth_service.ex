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

  def get_jwks() do
    case HTTPoison.get(jwks_endpoint()) do
      {:ok, %{body: body}} -> Jason.decode(body)
      error -> error
    end
  end

  defp user_info_endpoint() do
    Application.get_env(:discovery_api, :user_info_endpoint)
  end

  defp jwks_endpoint() do
    Application.get_env(:discovery_api, :jwks_endpoint)
  end
end

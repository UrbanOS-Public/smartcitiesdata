defmodule Andi.Services.AuthService do
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
      {:ok, %{body: body}} -> Jason.decode(body) |> IO.inspect(label: "JWKS")
      error -> error
    end
  end

  defp user_info_endpoint() do
    "https://smartcolumbusos-demo.auth0.com/userinfo"
  end

  defp jwks_endpoint() do
    "https://smartcolumbusos-demo.auth0.com/.well-known/jwks.json"
  end
end

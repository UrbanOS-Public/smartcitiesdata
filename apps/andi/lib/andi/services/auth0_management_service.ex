defmodule Andi.Services.Auth0Management do
  @moduledoc """
  Service to get a temporary access token for the auth0 managment api and interface with the api
  """
  use Properties, otp_app: :andi
  use Tesla

  require Logger

  getter(:auth0, generic: true)

  defp get_token() do
    url = Keyword.fetch!(auth0(), :url)
    audience = Keyword.fetch!(auth0(), :audience)

    req_body =
      URI.encode_query(%{grant_type: "client_credentials", client_id: client_id(), client_secret: client_secret(), audience: audience})

    case post(url, req_body, headers: [{"content-type", "application/x-www-form-urlencoded"}]) do
      {:ok, response} ->
        access_token = response |> Map.get(:body) |> Jason.decode!() |> Map.get("access_token")
        {:ok, access_token}

      {_, error} ->
        {:error, error}
    end
  end

  def get_roles() do
    url = Keyword.fetch!(auth0(), :audience)

    with {:ok, access_token} <- get_token(),
         {:ok, response} <- get("#{url}roles", headers: [{"Authorization", "Bearer #{access_token}"}]) do
      roles = response |> Map.get(:body) |> Jason.decode!()
      roles
    else
      {:error, reason} ->
        Logger.error("Unable to retrieve auth0 roles: #{reason}")
        {:error, :retrieve_auth0_roles_failed}
    end
  end

  def get_user_roles(subject_id) do
  end

  defp client_id() do
    ueberauth_config = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)

    Keyword.fetch!(ueberauth_config, :client_id)
  end

  defp client_secret() do
    ueberauth_config = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)

    Keyword.fetch!(ueberauth_config, :client_secret)
  end
end

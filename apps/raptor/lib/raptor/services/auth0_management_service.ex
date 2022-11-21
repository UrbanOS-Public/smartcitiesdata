defmodule Raptor.Services.Auth0Management do
  @moduledoc """
  Service to get a temporary access token for the auth0 managment api and interface with the api
  """
  use Properties, otp_app: :raptor
  use Tesla

  require Logger

  getter(:auth0, generic: true)

  def get_users_by_api_key(apiKey) do
    url = Keyword.fetch!(auth0(), :audience)

    with {:ok, access_token} <- get_token(),
         {:ok, response} <-
           get("#{url}users?q=app_metadata.apiKey:\"#{apiKey}\"&search_engine=v3",
             headers: [{"Authorization", "Bearer #{access_token}"}]
           ) do
      users = response |> Map.get(:body) |> Jason.decode!()
      {:ok, users}
    else
      {:error, reason} ->
        Logger.error("Unable to retrieve auth0 users with the provided api key: #{reason}")
        {:error, :retrieve_auth0_users_by_api_key_failed}
    end
  end

  def patch_api_key(apiKey) do
    #TODO: Test
    url = Keyword.fetch!(auth0(), :audience)

    IO.inspect(url, label: "Auth0 URL")
  end

  defp client_id() do
    ueberauth_config = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)

    Keyword.fetch!(ueberauth_config, :client_id)
  end

  defp client_secret() do
    ueberauth_config = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)

    Keyword.fetch!(ueberauth_config, :client_secret)
  end

  defp get_token() do
    url = Keyword.fetch!(auth0(), :url)
    audience = Keyword.fetch!(auth0(), :audience)

    req_body =
      URI.encode_query(%{
        grant_type: "client_credentials",
        client_id: client_id(),
        client_secret: client_secret(),
        audience: audience
      })

    case post(url, req_body, headers: [{"content-type", "application/x-www-form-urlencoded"}]) do
      {:ok, response} ->
        access_token = response |> Map.get(:body) |> Jason.decode!() |> Map.get("access_token")
        {:ok, access_token}

      {_, error} ->
        {:error, error}
    end
  end
end

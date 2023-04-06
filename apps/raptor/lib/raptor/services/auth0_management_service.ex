defmodule Raptor.Services.Auth0Management do
  @moduledoc """
  Service to get a temporary access token for the auth0 managment api and interface with the api
  """
  use Properties, otp_app: :raptor
  alias Tesla
  alias Raptor.Services.Auth0UserDataStore
  alias Raptor.Services.Auth0UserRoleStore
  alias Raptor.Schemas.Auth0UserData
  alias Raptor.Schemas.Auth0UserRole

  require Logger

  getter(:auth0, generic: true)

  @instance_name Raptor.instance_name()

  def get_users_by_api_key(apiKey) do
    case Auth0UserDataStore.get_user_by_api_key(apiKey) do
      [] ->
        user_list_results = get_users_by_api_key_from_auth0(apiKey)
        persist_user_list(user_list_results)
        user_list_results

      user_list ->
        {:ok, user_list}
    end
  end

  def get_roles_by_user_id(user_id) do
    case Auth0UserRoleStore.get_roles_by_user_id(user_id) do
      [] ->
        roles_response = get_roles_by_user_id_from_auth0(user_id)
        persist_roles(user_id, roles_response)
        roles_response

      roles ->
        {:ok, roles}
    end
  end

  defp get_users_by_api_key_from_auth0(apiKey) do
    url = Keyword.fetch!(auth0(), :audience)

    with {:ok, access_token} <- get_token(),
         {:ok, response} <-
           Tesla.get("#{url}users?q=app_metadata.apiKey:\"#{apiKey}\"&search_engine=v3",
             headers: [{"Authorization", "Bearer #{access_token}"}]
           ) do
      users =
        response
        |> Map.get(:body)
        |> Jason.decode!()
        |> Enum.map(&Auth0UserData.from_map/1)

      {:ok, users}
    else
      {:error, reason} ->
        Logger.error("Unable to retrieve auth0 users with the provided api key: #{reason}")
        {:error, :retrieve_auth0_users_by_api_key_failed}
    end
  end

  defp get_roles_by_user_id_from_auth0(user_id) do
    url = Keyword.fetch!(auth0(), :audience)
    full_url = "#{url}users/#{user_id}/roles"

    with {:ok, access_token} <- get_token(),
         {:ok, response} <-
           Tesla.get(full_url,
             headers: [{"Authorization", "Bearer #{access_token}"}]
           ) do
      users =
        response
        |> Map.get(:body)
        |> Jason.decode!()
        |> Enum.map(&Auth0UserRole.from_map/1)

      {:ok, users}
    else
      {:error, reason} ->
        Logger.error("Unable to retrieve auth0 user roles with the provided api key: #{reason}")
        {:error, :retrieve_auth0_user_roles_by_api_key_failed}
    end
  end

  def patch_api_key(userID, apiKey) do
    audience = Keyword.fetch!(auth0(), :audience)
    url = "#{audience}users/#{userID}"
    {:ok, access_token} = get_token()
    body = '{"app_metadata": {"apiKey": "#{apiKey}"}}'
    headers = [{"Authorization", "Bearer #{access_token}"}, {"Content-Type", "application/json"}]
    {:ok, response} = HTTPoison.patch(url, body, headers, [])

    if response.status_code >= 400 do
      {:error, response.body}
    else
      {:ok, response}
    end
  end

  def is_valid_user(%Auth0UserData{} = user) do
    if user.email_verified and !user.blocked, do: true, else: false
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

    case Tesla.post(url, req_body,
           headers: [{"content-type", "application/x-www-form-urlencoded"}]
         ) do
      {:ok, response} ->
        access_token = response |> Map.get(:body) |> Jason.decode!() |> Map.get("access_token")
        {:ok, access_token}

      {_, error} ->
        {:error, error}
    end
  end

  defp persist_user_list(user_list_results) do
    case user_list_results do
      {:ok, user_list} ->
        user_list
        |> Enum.each(fn
          user_data -> Raptor.Services.Auth0UserDataStore.persist(user_data)
        end)

      {:error, reason} ->
        :error
    end
  end

  defp persist_roles(user_id, roles_results) do
    case roles_results do
      {:ok, roles} ->
        Raptor.Services.Auth0UserRoleStore.persist(user_id, roles)

      {:error, reason} ->
        :error
    end
  end
end

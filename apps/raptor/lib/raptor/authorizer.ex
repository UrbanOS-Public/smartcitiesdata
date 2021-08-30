defmodule Raptor.Authorizer do
  alias Raptor.Services.Auth0Management
  require Logger

  def validate_user_list(user_list) do
    case length(user_list) do
      0 ->
        Logger.error("No user found with given API Key.")
        false

      1 ->
        user = user_list |> Enum.at(0)
        # Only users who have validated their email address may make API calls
        user["email_verified"]

      _ ->
        Logger.error("Multiple users cannot have the same API Key.")
        false
    end
  end

  def authorize(apiKey) do
    case Auth0Management.get_users_by_api_key(apiKey) do
      {:ok, user_list} -> validate_user_list(user_list)
      {:error, _} -> false
    end
  end
end

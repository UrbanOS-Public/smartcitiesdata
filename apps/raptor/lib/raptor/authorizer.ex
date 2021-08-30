defmodule Raptor.Authorizer do
  alias Raptor.Services.Auth0Management

  def validate_user_list(user_list) do
    case user_list do
      [] -> false
      _ -> true
    end
  end

  def authorize(apiKey) do
    case Auth0Management.get_users_by_api_key(apiKey) do
      {:ok, user_list} -> validate_user_list(user_list)
      {:error, _} -> false
    end
  end
end

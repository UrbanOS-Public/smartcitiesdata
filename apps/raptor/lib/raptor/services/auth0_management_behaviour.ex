defmodule Raptor.Services.Auth0ManagementBehaviour do
  @callback get_users_by_api_key(String.t()) :: {:ok, list()} | {:error, any()}
  @callback is_valid_user(map()) :: boolean()
end

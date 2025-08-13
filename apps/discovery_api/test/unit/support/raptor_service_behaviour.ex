defmodule RaptorServiceBehaviour do
  @moduledoc """
  Behaviour for the RaptorService module to enable mocking
  """
  
  @callback list_access_groups_by_dataset(binary(), binary()) :: map()
  @callback list_groups_by_user(binary(), binary()) :: map()
  @callback list_groups_by_api_key(binary(), binary()) :: map()
  @callback is_authorized(binary(), binary(), binary()) :: boolean()
  @callback is_authorized_by_user_id(binary(), binary(), binary()) :: boolean()
  @callback regenerate_api_key_for_user(binary(), binary()) :: {:ok, map()} | {:error, binary()}
  @callback get_user_id_from_api_key(binary(), binary()) :: {:ok, binary()} | {:error, binary(), integer()}
  @callback check_auth0_role(binary(), binary(), binary()) :: {:ok, boolean()} | {:error, binary(), integer()}
end
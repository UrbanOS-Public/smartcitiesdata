defmodule QueryAccessUtilsBehaviour do
  @moduledoc """
  Behaviour for QueryAccessUtils module to enable mocking
  """
  
  @callback authorized_session(any(), any()) :: {:ok, any()} | {:error, binary()}
  @callback user_is_authorized?(any(), any(), any()) :: boolean()
  @callback get_affected_models(binary()) :: {:ok, list()} | {:error, binary()} | {:sql_error, binary()}
  @callback user_can_access_models?(any(), any()) :: boolean()
  @callback api_key_can_access_models?(any(), list()) :: boolean()
end
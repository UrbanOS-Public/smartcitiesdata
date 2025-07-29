defmodule RaptorServiceBehaviour do
  @moduledoc false
  # Mox mock for RaptorService
  
  @callback is_authorized(String.t(), String.t(), String.t()) :: boolean()
  @callback get_user_id_from_api_key(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t(), String.t()}
end
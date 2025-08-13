defmodule SystemNameCacheBehaviour do
  @moduledoc """
  Behaviour for SystemNameCache module to enable mocking
  """
  
  @callback get(binary(), binary()) :: binary() | nil
  @callback delete(binary(), binary()) :: {:ok, any()} | {:error, any()}
end
defmodule OrganizationsBehaviour do
  @moduledoc """
  Behaviour for Organizations module to enable mocking
  """
  
  @callback create_or_update(any()) :: any()
  @callback get_organization(binary()) :: {:ok, any()} | {:error, any()}
end
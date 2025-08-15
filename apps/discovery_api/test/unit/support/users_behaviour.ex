defmodule UsersBehaviour do
  @moduledoc """
  Behaviour for the Users module to enable mocking
  """
  
  @callback get_user_with_organizations(any(), atom()) :: {:ok, any()} | {:error, any()}
  @callback get_user(any(), atom()) :: {:ok, any()} | {:error, any()}
  @callback create(map()) :: {:ok, any()} | {:error, any()}
  @callback associate_with_organization(any(), any()) :: {:ok, any()} | {:error, any()}
  @callback disassociate_with_organization(any(), any()) :: {:ok, any()} | {:error, any()}
end
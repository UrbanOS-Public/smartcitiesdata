defmodule DiscoveryApi.Data.PersistenceBehaviour do
  @moduledoc """
  Behaviour for the Persistence module to enable mocking
  """
  
  @callback get_keys(binary()) :: list()
  @callback get_many(list(), boolean()) :: list()
  @callback get_many(list()) :: list() 
  @callback get_many_with_keys(list()) :: map()
  @callback delete(binary()) :: any()
  @callback persist(binary(), any()) :: any()
  @callback get(binary()) :: any()
end
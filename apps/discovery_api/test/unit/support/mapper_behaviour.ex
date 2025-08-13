defmodule MapperBehaviour do
  @moduledoc """
  Behaviour for the Mapper module to enable mocking
  """
  
  @callback to_data_model(any(), any()) :: {:ok, any()} | {:error, any()}
  @callback add_access_group(any(), any()) :: any()
  @callback remove_access_group(any(), any()) :: any()
end
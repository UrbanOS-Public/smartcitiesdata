defmodule BrookBehaviour do
  @moduledoc """
  Behaviour for Brook module to enable mocking
  """
  
  @callback get(atom(), atom(), any()) :: {:ok, any()} | {:error, any()}
end
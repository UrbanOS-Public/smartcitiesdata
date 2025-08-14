defmodule BrookBehaviour do
  @moduledoc """
  Behaviour for Brook module to enable mocking
  """
  
  @callback get(atom(), atom(), any()) :: {:ok, any()} | {:error, any()}
  @callback send(atom(), atom(), atom(), any()) :: :ok | {:error, any()}
end
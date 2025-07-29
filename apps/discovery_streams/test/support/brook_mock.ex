defmodule BrookMock do
  @moduledoc false
  # Mox mock for Brook service
  
  @callback get(atom(), atom(), any()) :: {:ok, term()} | {:error, String.t()}
  @callback get!(atom(), atom(), any()) :: any() | nil
  @callback get_all(atom(), atom()) :: {:ok, map()} | {:error, String.t()}
  @callback create(atom(), atom(), any(), any()) :: :ok | {:error, any()}
  @callback delete(atom(), atom(), any()) :: :ok | {:error, any()}
end
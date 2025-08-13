defmodule RedixBehaviour do
  @moduledoc """
  Behavior for Redix operations to enable mocking in tests
  """

  @callback command(atom(), list()) :: {:ok, term()} | {:error, term()}
  @callback command!(atom(), list()) :: term()
end
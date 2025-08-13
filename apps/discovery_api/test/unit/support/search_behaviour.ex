defmodule SearchBehaviour do
  @moduledoc """
  Behaviour for the Search module to enable mocking
  """
  
  @callback search(keyword()) :: {:ok, list(), map(), integer()} | {:error, any()}
end
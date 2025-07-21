defmodule Guardian.Behaviour do
  @callback decode_and_verify(String.t(), map(), Keyword.t(), Keyword.t()) :: {:ok, map()} | {:error, any()}
end

defmodule HTTPoison.Behaviour do
  @callback get(String.t(), Keyword.t()) :: {:ok, map()} | {:error, any()}
end

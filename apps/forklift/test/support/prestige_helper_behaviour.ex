defmodule Forklift.Test.PrestigeHelperBehaviour do
  @callback count_query(String.t()) :: {:ok, integer()} | {:error, term()}
end

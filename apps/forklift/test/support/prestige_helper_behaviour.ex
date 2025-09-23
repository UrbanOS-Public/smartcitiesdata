defmodule Forklift.Test.PrestigeHelperBehaviour do
  @callback count_query(String.t()) :: {:ok, integer()} | {:error, term()}
  @callback table_exists?(String.t()) :: boolean()
end

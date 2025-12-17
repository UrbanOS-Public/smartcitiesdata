defmodule Forklift.Test.PrestigeHelperBehaviour do
  @moduledoc """
  Test behaviour for mocking Prestige helper operations.
  """
  @callback count_query(String.t()) :: {:ok, integer()} | {:error, term()}
  @callback table_exists?(String.t()) :: boolean()
end

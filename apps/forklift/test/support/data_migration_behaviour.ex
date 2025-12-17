defmodule Forklift.Test.DataMigrationBehaviour do
  @moduledoc """
  Test behaviour for mocking data migration operations.
  """
  @callback compact(any(), any(), any()) :: {:ok, any()} | {:error, any()}
end

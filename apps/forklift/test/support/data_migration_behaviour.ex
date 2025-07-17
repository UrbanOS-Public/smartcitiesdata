defmodule Forklift.Test.DataMigrationBehaviour do
  @callback compact(any(), any(), any()) :: {:ok, any()} | {:error, any()}
end

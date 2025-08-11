defmodule Reaper.CacheBehaviour do
  @callback mark_duplicates(atom(), any()) :: {:ok, any()} | {:duplicate, any()} | {:error, any()}
  @callback cache(atom(), any()) :: {:ok, boolean()} | {:error, any()}
end
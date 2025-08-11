defmodule Reaper.ExAwsBehaviour do
  @callback request(any()) :: {:ok, any()} | {:error, any()}
  @callback request(any(), any()) :: {:ok, any()} | {:error, any()}
end
defmodule Reaper.MintHttpBehaviour do
  @callback connect(atom(), String.t(), pos_integer(), keyword()) :: {:ok, any()} | {:error, any()}
  @callback request(any(), String.t(), String.t(), list(), String.t()) :: {:ok, any(), any()} | {:error, any()}
  @callback stream(any(), any()) :: {:ok, any(), list()} | {:error, any()}
  @callback close(any()) :: any()
end
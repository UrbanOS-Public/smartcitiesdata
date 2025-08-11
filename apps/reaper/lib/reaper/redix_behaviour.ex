defmodule Reaper.RedixBehaviour do
  @callback start_link(keyword()) :: {:ok, pid()} | {:error, any()}
  @callback command(pid(), list()) :: {:ok, any()} | {:error, any()}
  @callback command!(pid(), list()) :: any() | no_return()
end
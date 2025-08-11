defmodule Reaper.BrookEventBehaviour do
  @callback send(any(), any(), any(), any()) :: :ok | {:error, any()}
end
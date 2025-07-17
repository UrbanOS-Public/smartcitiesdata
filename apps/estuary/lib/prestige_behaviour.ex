defmodule Estuary.PrestigeBehaviour do
  @callback new_session(any()) :: any()
  @callback stream!(any(), any()) :: any()
end

defmodule PrestigeBehaviour do
  @moduledoc """
  Behaviour for the Prestige module to enable mocking
  """
  
  @callback new_session(any()) :: any()
  @callback query!(any(), binary()) :: any()
  @callback stream!(any(), binary()) :: any()
  @callback prepare!(any(), binary(), map()) :: any()
  @callback execute!(any(), any()) :: any()
end
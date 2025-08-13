defmodule PrestigeBehaviour do
  @moduledoc """
  Behaviour for the Prestige module to enable mocking
  """
  
  @callback new_session(any()) :: any()
  @callback query!(any(), binary()) :: any()
  @callback stream!(any(), binary()) :: any()
end
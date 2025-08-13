defmodule PrestigeResultBehaviour do
  @moduledoc """
  Behaviour for the Prestige.Result module to enable mocking
  """
  
  @callback as_maps(any()) :: any()
end
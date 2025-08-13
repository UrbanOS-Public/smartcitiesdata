defmodule ModelAccessUtilsBehaviour do
  @moduledoc """
  Behaviour for the ModelAccessUtils module to enable mocking
  """
  
  @callback has_access?(any(), any()) :: boolean()
end
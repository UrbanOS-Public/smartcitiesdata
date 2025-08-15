defmodule DateTimeBehaviour do
  @moduledoc """
  Behaviour for the DateTime module to enable mocking
  """
  
  @callback utc_now() :: DateTime.t()
end
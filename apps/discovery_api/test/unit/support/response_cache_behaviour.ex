defmodule ResponseCacheBehaviour do
  @moduledoc """
  Behaviour for ResponseCache module to enable mocking
  """
  
  @callback invalidate() :: any()
end
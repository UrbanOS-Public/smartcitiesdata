defmodule TableInfoCacheBehaviour do
  @moduledoc """
  Behaviour for the TableInfoCache module to enable mocking
  """
  
  @callback put(any(), any()) :: any()
  @callback get(any()) :: any() | nil
  @callback invalidate() :: any()
end
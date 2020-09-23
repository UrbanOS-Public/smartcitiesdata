defmodule Performance.SetupConfig do
  @moduledoc """
  A common struct for performance test scenario setup
  """
  defstruct [
    :messages,
    prefetch_count: 0,
    prefetch_bytes: 1_000_000,
    max_bytes: 1_000_000,
    max_wait_time: 10_000,
    min_bytes: 0
  ]
end

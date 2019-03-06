defmodule Reaper.Partitioner do
  @callback partition(String.t(), String.t()) :: String.t()
end

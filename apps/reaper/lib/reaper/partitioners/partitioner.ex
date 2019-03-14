defmodule Reaper.Partitioner do
  @moduledoc false
  @callback partition(String.t(), String.t()) :: String.t()
end

defmodule Reaper.Partitioners.SinglePartitioner do
  @moduledoc false
  @behaviour Reaper.Partitioner

  def partition(message, path) do
    "SINGLE"
  end
end

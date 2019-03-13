defmodule Reaper.Partitioners.SinglePartitioner do
  @moduledoc false
  @behaviour Reaper.Partitioner

  def partition(_message, _path) do
    "SINGLE"
  end
end

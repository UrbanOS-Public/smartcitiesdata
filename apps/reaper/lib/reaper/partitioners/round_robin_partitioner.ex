defmodule Reaper.Partitioners.RoundRobinPartitioner do
  @moduledoc false
  @behaviour Reaper.Partitioner

  def partition(_message, _filter) do
    nil
  end
end

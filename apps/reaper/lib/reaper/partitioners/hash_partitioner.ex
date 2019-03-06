defmodule Reaper.Partitioners.HashPartitioner do
  @moduledoc false
  @behaviour Reaper.Partitioner

  def partition(payload, filter) do
    md5(Kernel.inspect(payload))
  end

  defp md5(thing), do: :crypto.hash(:md5, thing) |> Base.encode16()
end

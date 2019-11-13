defmodule Reaper.Partitioners.HashPartitioner do
  @moduledoc false
  @behaviour Reaper.Partitioner

  def partition(payload, _filter) do
    md5(inspect(payload))
  end

  defp md5(thing), do: :crypto.hash(:md5, thing) |> Base.encode16()
end

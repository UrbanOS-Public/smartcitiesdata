defmodule Reaper.Partitioners.JsonPartitioner do
  @moduledoc false
  @behaviour Reaper.Partitioner

  def partition(payload, path) do
    filter =
      path
      |> String.split(".")
      |> Enum.map(&String.to_atom/1)

    Jason.decode!(payload, keys: :atoms)
    |> get_in(filter)
  end
end

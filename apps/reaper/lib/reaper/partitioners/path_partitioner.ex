defmodule Reaper.Partitioners.PathPartitioner do
  @moduledoc false
  @behaviour Reaper.Partitioner

  def partition(payload, path) do
    filter =
      path
      |> String.split(".")
      |> Enum.map(&format_key(payload, &1))
      |> Enum.map(&Access.key/1)

    payload
    |> get_in(filter)
  end

  defp format_key(%_struct{}, path_elem) do
    String.to_atom(path_elem)
  end

  defp format_key(_payload, path_elem), do: path_elem
end

defmodule Reaper.Util do
  @moduledoc false
  def via_tuple(id), do: {:via, Horde.Registry, {Reaper.Horde.Registry, id}}

  def deep_merge(left, right), do: Map.merge(left, right, &deep_resolve/3)
  defp deep_resolve(_key, %{} = left, %{} = right), do: deep_merge(left, right)
  defp deep_resolve(_key, _left, right), do: right

  def get_header_value(headers, header_name) do
    case Enum.find(headers, fn {name, _value} -> String.downcase(name) == String.downcase(header_name) end) do
      nil -> nil
      {_header, value} -> value
    end
  end
end

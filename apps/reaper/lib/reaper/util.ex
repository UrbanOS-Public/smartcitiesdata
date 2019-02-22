defmodule Reaper.Util do
  @moduledoc false

  def deep_merge(left, right), do: Map.merge(left, right, &deep_resolve/3)
  defp deep_resolve(_key, %{} = left, %{} = right), do: deep_merge(left, right)
  defp deep_resolve(_key, _left, right), do: right
end

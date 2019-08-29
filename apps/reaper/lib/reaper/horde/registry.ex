defmodule Reaper.Horde.Registry do
  @moduledoc """
  Module based Horde.Registry
  """
  use Horde.Registry

  def init(options) do
    {:ok, Keyword.put(options, :members, get_members())}
  end

  defp get_members() do
    [Node.self() | Node.list()]
    |> Enum.map(fn node -> {__MODULE__, node} end)
  end
end

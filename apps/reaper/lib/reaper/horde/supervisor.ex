defmodule Reaper.Horde.Supervisor do
  @moduledoc """
  Module Based Horde.Supervisor
  """
  use Horde.Supervisor

  def init(options) do
    {:ok, Keyword.put(options, :members, get_members())}
  end

  defp get_members() do
    [Node.self() | Node.list()]
    |> Enum.map(fn node -> {__MODULE__, node} end)
  end
end

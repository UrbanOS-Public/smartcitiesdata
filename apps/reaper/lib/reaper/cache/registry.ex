defmodule Reaper.Cache.Registry do
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

  def get_all() do
    Horde.Registry.select(__MODULE__, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  def lookup(key) do
    case Horde.Registry.lookup(__MODULE__, key) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end
end

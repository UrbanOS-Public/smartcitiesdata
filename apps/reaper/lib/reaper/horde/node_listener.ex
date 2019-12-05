defmodule Reaper.Horde.NodeListener do
  @moduledoc """
  Listens to node events and updates membership to horde clusters
  """
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    :net_kernel.monitor_nodes(true, node_type: :visible)
    {:ok, %{hordes: Keyword.fetch!(opts, :hordes)}}
  end

  def handle_info({:nodeup, _node, _}, state) do
    Enum.each(state.hordes, fn horde -> set_members(horde) end)
    {:noreply, state}
  end

  def handle_info({:nodedown, _node, _}, state) do
    Enum.each(state.hordes, fn horde -> set_members(horde) end)
    {:noreply, state}
  end

  defp set_members(name) do
    members =
      [Node.self() | Node.list()]
      |> Enum.map(fn node -> {name, node} end)

    :ok = Horde.Cluster.set_members(name, members)
  end
end

defmodule TestUtils do
  @moduledoc false
  def feed_supervisor_count() do
    Reaper.Horde.Supervisor
    |> Horde.Supervisor.which_children()
    |> Enum.filter(&is_feed_supervisor?/1)
    |> Enum.count()
  end

  def get_child_pids_for_feed_supervisor(name) do
    Reaper.Registry
    |> Horde.Registry.lookup(name)
    |> Horde.Supervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.sort()
  end

  def child_count(module) do
    Reaper.Horde.Supervisor
    |> Horde.Supervisor.which_children()
    |> Enum.filter(&is_feed_supervisor?/1)
    |> Enum.flat_map(&get_supervisor_children/1)
    |> Enum.filter(fn {_, _, _, [mod]} -> mod == module end)
    |> Enum.count()
  end

  defp is_feed_supervisor?([{_, _, _, [mod]}]) do
    mod == Reaper.FeedSupervisor
  end

  defp is_feed_supervisor?([]), do: false

  defp get_supervisor_children([{_, pid, _, _}]) do
    Supervisor.which_children(pid)
  end

  defp get_supervisor_children([]), do: []
end

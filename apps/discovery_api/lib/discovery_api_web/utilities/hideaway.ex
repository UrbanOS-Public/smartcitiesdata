defmodule DiscoveryApiWeb.Utilities.Hideaway do
  @moduledoc """
    This module tracks state in a parallel process to support streamed dataset downloads
  """
  use Agent

  def start(initial_value) do
    Agent.start(fn -> initial_value end)
  end

  def stash(pid, new_value) do
    Agent.update(pid, fn _ ->
      new_value
    end)

    new_value
  end

  def retrieve(pid) do
    Agent.get(pid, fn state ->
      state
    end)
  end

  def destroy(pid) do
    Process.exit(pid, :done)
  end
end

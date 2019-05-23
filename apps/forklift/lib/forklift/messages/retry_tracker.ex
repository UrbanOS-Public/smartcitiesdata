defmodule Forklift.Messages.RetryTracker do
  @moduledoc """
  Simple agent for storing how many retries a dataset has gone through.
  """
  use Agent
  require Logger

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def get_and_increment_retries(dataset_id) do
    Agent.get_and_update(__MODULE__, fn state ->
      Map.get_and_update(state, dataset_id, fn
        nil -> {0, 0}
        x -> {x, x + 1}
      end)
    end)

    Agent.get(__MODULE__, fn state ->
      state[dataset_id]
    end)
  end

  def reset_retries(dataset_id) do
    Agent.update(__MODULE__, fn s ->
      Map.put(s, dataset_id, 0)
    end)
  end
end

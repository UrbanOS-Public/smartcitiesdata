defmodule Forklift.RetryTracker do
  @moduledoc false
  use Agent
  require Logger

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def mark_retry(dataset_id) do
    Agent.get_and_update(__MODULE__, fn state ->
      Map.get_and_update(state, dataset_id, fn
        nil -> {0, 0}
        x -> {x, x + 1}
      end)
    end)
  end

  def get_retries(dataset_id) do
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

defmodule Forklift.EmptyStreamTracker do
  @moduledoc false
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def get_and_update_empty_reads(dataset_id) do
    Agent.get_and_update(__MODULE__, fn state ->
      Map.get_and_update(state, dataset_id, fn
        nil -> {0, 0}
        x -> {x, x + 1}
      end)
    end)
  end

  def reset_empty_reads(dataset_id) do
    Agent.update(__MODULE__, fn s ->
      Map.put(s, dataset_id, 0)
    end)
  end

  def delete_stream_ref(dataset_id) do
    Agent.update(__MODULE__, &Map.delete(&1, dataset_id))
  end
end

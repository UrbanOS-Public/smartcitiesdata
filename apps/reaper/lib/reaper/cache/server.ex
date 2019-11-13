defmodule Reaper.Cache.Server do
  @moduledoc false
  use GenServer

  @default_size 2_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :name))
  end

  def init(opts) do
    size = Keyword.get(opts, :size, @default_size)
    {:ok, %{size: size, queue: :queue.new()}}
  end

  def handle_cast({:put, value}, state) do
    new_queue = :queue.in(value, state.queue)

    {:noreply, %{state | queue: ensure_size_of_queue(new_queue, state.size)}}
  end

  def handle_call({:exists?, value}, _from, state) do
    {:reply, :queue.member(value, state.queue), state}
  end

  defp ensure_size_of_queue(queue, size) do
    case :queue.len(queue) > size do
      true ->
        {_value, new_queue} = :queue.out(queue)
        new_queue

      false ->
        queue
    end
  end
end

defmodule Odo.Support.TestEventHandler do
  @moduledoc false
  use Brook.Event.Handler

  def child_spec(_opts) do
    %{
      id: Agent,
      start: {Agent, :start_link, [fn -> [] end, [name: __MODULE__]]}
    }
  end

  def get_events do
    Agent.get(__MODULE__, & &1)
  end

  def handle_event(event) do
    if agent_alive?() do
      new_event = Map.from_struct(event) |> Map.delete(:create_ts)
      Agent.update(__MODULE__, fn events -> [new_event | events] end)
    end

    :discard
  end

  defp agent_alive? do
    case Process.whereis(__MODULE__) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end
end

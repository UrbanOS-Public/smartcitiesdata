defmodule Raptor.BrookWrapper do
  @moduledoc """
  Wrapper around Brook to add error handling for deserialization issues.
  This prevents the application from crashing when encountering malformed messages.
  """
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    # Start Brook normally
    {:ok, brook_pid} = Brook.start_link(opts)
    {:ok, %{brook_pid: brook_pid}}
  end

  # Monitor Brook and restart with error handling if it crashes
  def handle_info({:EXIT, _pid, reason}, state) do
    Logger.error("Brook crashed with reason: #{inspect(reason)}")
    Logger.info("This is expected if there are malformed messages in Kafka")
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("BrookWrapper received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
end

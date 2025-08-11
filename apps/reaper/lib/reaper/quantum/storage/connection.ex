defmodule Reaper.Quantum.Storage.Connection do
  @moduledoc false
  use GenServer
  use Properties, otp_app: :reaper
  require Logger

  @conn :reaper_quantum_storage_redix
  @restart_delay 2_000

  getter(:redix_client, default: Redix, generic: true)

  @redix_opts [
    name: @conn,
    timeout: 10_000,
    sync_connect: true,
    exit_on_disconnection: true
  ]

  def connection(), do: @conn

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(args) do
    Process.flag(:trap_exit, true)

    config = Keyword.merge(args, @redix_opts)

    case redix_client().start_link(config) do
      {:ok, pid} ->
        Logger.info("#{__MODULE__} : Redix successfully connected")
        {:ok, pid}

      {:error, reason} ->
        Logger.warn("#{__MODULE__} : Redix failed to start,  #{inspect(reason)}")
        Process.sleep(@restart_delay)
        {:stop, reason}
    end
  catch
    :exit, reason ->
      Logger.warn("#{__MODULE__} : Redix exited during boot, #{inspect(reason)}")
      Process.sleep(@restart_delay)
      {:stop, reason}
  end

  @impl GenServer
  def handle_info({:EXIT, _, reason}, state) do
    Logger.warn("#{__MODULE__} : Received exit from redix, terminating")
    Process.sleep(@restart_delay)
    {:stop, reason, state}
  end
end

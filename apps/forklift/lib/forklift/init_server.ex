defmodule Forklift.InitServer do
  @moduledoc """
  Task to initialize forklift and start ingesting each previously recorded dataset
  """
  use GenServer

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def init(_) do
    with :ok <- Forklift.DataWriter.bootstrap(),
         :ok <- init_readers(),
         pid <- Process.whereis(Pipeline.DynamicSupervisor) do
      Process.monitor(pid)
      {:ok, %{pipeline: pid}}
    end
  end

  def handle_info({:DOWN, _, _, pid, _}, %{pipeline: pid}) do
    # Wait for supervisor to restart, then re-monitor and re-initialize
    wait_for_supervisor_restart()
    :ok = init_readers()
    new_pid = Process.whereis(Pipeline.DynamicSupervisor)
    if new_pid, do: Process.monitor(new_pid)
    {:noreply, %{pipeline: new_pid}}
  end

  defp wait_for_supervisor_restart(retries \\ 50) do
    case Process.whereis(Pipeline.DynamicSupervisor) do
      nil when retries > 0 ->
        Process.sleep(10)
        wait_for_supervisor_restart(retries - 1)

      nil ->
        :supervisor_restart_timeout

      _pid ->
        :ok
    end
  end

  defp init_readers do
    Forklift.Datasets.get_all!()
    |> Enum.map(&initialize/1)
    |> validate_inits()
  end

  defp initialize(dataset) do
    Process.sleep(250)
    Forklift.DataReaderHelper.init(dataset)
  end

  defp validate_inits(results) do
    case Enum.reject(results, fn res -> res == :ok end) do
      [] -> :ok
      [error | _] -> {:error, error}
    end
  end
end

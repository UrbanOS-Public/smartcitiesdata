defmodule Estuary.InitServer do
  @moduledoc """
  Task to initialize estuary and start ingesting each previously recorded dataset
  """
  use GenServer

  alias Estuary.DataReader
  alias Estuary.Datasets.DatasetSchema
  alias Estuary.DataWriter

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def init(_) do
    with :ok <- init_writer(),
         :ok <- DataReader.init(),
         pid when is_pid(pid) <- Process.whereis(Pipeline.DynamicSupervisor) do
      Process.monitor(pid)
      {:ok, %{pipeline: pid}}
    else
      _ -> raise "Could not initialize Estuary"
    end
  end

  def handle_info({:DOWN, _, _, pid, _} = msg, %{pipeline: pid} = state) do
    with :ok <- DataReader.init(),
         pid when is_pid(pid) <- Process.whereis(Pipeline.DynamicSupervisor) do
      Process.monitor(pid)
      {:noreply, %{pipeline: pid}}
    else
      _ ->
        Process.sleep(100)
        handle_info(msg, state)
    end
  end

  defp init_writer do
    DatasetSchema.table_schema()
    |> DataWriter.init()
  end
end

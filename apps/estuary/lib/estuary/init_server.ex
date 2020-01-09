defmodule Estuary.InitServer do
  @moduledoc """
  Task to initialize estuary and start ingesting each previously recorded dataset
  """
  use GenServer

  alias Estuary.DataReader
  alias Estuary.Datasets.DatasetSchema
  alias Estuary.DataWriter

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
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

  def handle_info({:DOWN, _, _, pid, _}, %{pipeline: pid} = state) do
    {:stop, "Could not re-initialize; #{inspect(pid)} died", state}
  end

  defp init_writer do
    DatasetSchema.table_schema()
    |> DataWriter.init()
  end
end

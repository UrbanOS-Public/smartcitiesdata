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
         pid <- Process.whereis(Pipeline.DynamicSupervisor) do
      Process.monitor(pid)
      {:ok, %{pipeline: pid}}
    end
  end

  def handle_info({:DOWN, _, _, pid, _}, %{pipeline: pid}) do
    :ok = DataReader.init()
    {:noreply, %{pipeline: Process.whereis(Pipeline.DynamicSupervisor)}}
  end

  defp init_writer do
    DatasetSchema.table_schema()
    |> DataWriter.init()
  end
end

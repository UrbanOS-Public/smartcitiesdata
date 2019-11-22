defmodule Estuary.Worker do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, :no_args, name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}}
  end
end

defmodule Reaper.Extraction.Supervisor do
  use Supervisor, restart: :temporary

  def start_link(opts) do
    dataset = Keyword.fetch!(opts, :dataset)
    name = {:via, Horde.Registry, {Reaper.Horde.Registry, :"#{dataset.id}_extraction_supervisor"}}
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    children = [
      {Reaper.ExtractionTask, [Keyword.fetch!(opts, :dataset)]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule NateServer do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(_opts) do
    {:ok, [], {:continue, :die}}
  end

  def handle_continue(:die, state) do
    {:stop, :i_hate_my_life, state}
  end
end

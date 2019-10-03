defmodule Forklift.Init do
  @moduledoc """
  Task to initialize forklift and start ingesting each previously recorded dataset
  """
  use Task, restart: :transient

  alias Forklift.Messages.MessageHandler

  @reader Application.get_env(:forklift, :data_reader)

  def start_link(_opts) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    Forklift.Datasets.get_all!()
    |> Enum.map(&reader_init_args/1)
    |> Enum.each(fn args -> @reader.init(args) end)
  end

  defp reader_init_args(dataset) do
    [app: :forklift, handler: MessageHandler, dataset: dataset]
  end
end

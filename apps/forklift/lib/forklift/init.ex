defmodule Forklift.Init do
  @moduledoc """
  Task to initialize forklift and start ingesting each previously recorded dataset
  """
  use Task, restart: :transient

  alias Forklift.Messages.MessageHandler
  alias Forklift.Datasets.DatasetHandler

  def start_link(_opts) do
    data_reader = Application.get_env(:forklift, :data_reader)
    Task.start_link(__MODULE__, :run, [data_reader])
  end

  def run(reader) do
    Brook.get_all_values!(:forklift, :datasets_to_process)
    |> Enum.map(&reader_init_args/1)
    |> Enum.each(fn args -> reader.init(args) end)
  end

  defp reader_init_args(dataset) do
    [app: :forklift, handler: MessageHandler, dataset: dataset]
  end
end

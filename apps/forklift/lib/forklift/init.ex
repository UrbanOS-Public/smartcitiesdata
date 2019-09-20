defmodule Forklift.Init do
  @moduledoc """
  Task to initialize forklift and start ingesting each previously recorded dataset
  """
  use Task, restart: :transient

  alias Forklift.Datasets.DatasetHandler

  def start_link(_opts) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    Brook.get_all_values!(:datasets_to_process)
    |> Enum.each(&DatasetHandler.start_dataset_ingest/1)
  end
end

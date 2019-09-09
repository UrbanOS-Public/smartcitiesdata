defmodule Reaper.Init do
  @moduledoc """
  Task to initialize reaper and send all reaper configs to the config server
  """
  use Task, restart: :transient

  alias Reaper.Collections.Extractions
  alias Reaper.Collections.FileIngestions

  def start_link(_opts) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    Extractions.get_all_non_completed!()
    |> Enum.each(fn %{dataset: dataset} ->
      Reaper.Horde.Supervisor.start_data_extract(dataset)
    end)

    FileIngestions.get_all_non_completed!()
    |> Enum.each(fn %{dataset: dataset} ->
      Reaper.Horde.Supervisor.start_file_ingest(dataset)
    end)
  end
end

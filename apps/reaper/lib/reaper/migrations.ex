defmodule Reaper.Migrations do
  @moduledoc """
  Contains all migrations that run during bootup.
  """
  use GenServer, restart: :transient

  import SmartCity.Event, only: [dataset_update: 0]
  alias Reaper.Persistence

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    migrate_last_fetched_timestamps()

    {:ok, :ok, {:continue, :stop}}
  end

  defp migrate_last_fetched_timestamps() do
    brook_config = Application.get_env(:reaper, :brook) |> Keyword.delete(:driver)
    {:ok, brook} = Brook.start_link(brook_config)

    Brook.get_all_values!(:reaper_config)
    |> Enum.map(fn reaper_config ->
      %{
        dataset: find_dataset_by_reaper_config(reaper_config),
        last_fetched_timestamp: Persistence.get_last_fetched_timestamp(reaper_config.dataset_id),
        started_timestamp: DateTime.from_unix!(0)
       }
    end)
    |> Enum.each(fn %{dataset: dataset} = map ->
      Brook.Test.save_view_state(:extractions, dataset.id, map)
    end)

    Process.unlink(brook)
    Supervisor.stop(brook)
  end

  def handle_continue(:stop, state) do
    {:stop, :normal, state}
  end

  defp find_dataset_by_reaper_config(reaper_config)  do
    Brook.get_events!(:reaper_config, reaper_config.dataset_id)
    |> Enum.filter(fn event -> event.type == dataset_update() end)
    |> List.last()
    |> Map.get(:data)
  end

end

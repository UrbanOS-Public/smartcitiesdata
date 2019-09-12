defmodule Reaper.Migrations do
  @moduledoc """
  Contains all migrations that run during bootup.
  """
  use GenServer, restart: :transient

  import SmartCity.Event, only: [dataset_update: 0]
  alias Reaper.Persistence
  alias Reaper.Collections.Extractions
  alias Reaper.Collections.FileIngestions

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
    |> Enum.each(&migrate_reaper_config/1)

    Process.unlink(brook)
    Supervisor.stop(brook)
  end

  defp migrate_reaper_config(reaper_config) do
    dataset_update = find_dataset_update(reaper_config)
    dataset = dataset_update.data
    last_fetched_timestamp = Persistence.get_last_fetched_timestamp(dataset.id)

    Brook.Test.with_event(dataset_update, fn ->
      setup_view_state(dataset, last_fetched_timestamp)
      Brook.ViewState.delete(:reaper_config, dataset.id)

      maybe_create_job(dataset)
      Persistence.remove_last_fetched_timestamp(dataset.id)
    end)
  end

  defp setup_view_state(%SmartCity.Dataset{technical: %{sourceType: "host"}} = dataset, timestamp) do
    FileIngestions.update_dataset(dataset, DateTime.from_unix!(0))
    FileIngestions.update_last_fetched_timestamp(dataset.id, timestamp)
  end

  defp setup_view_state(dataset, timestamp) do
    Extractions.update_dataset(dataset, DateTime.from_unix!(0))
    Extractions.update_last_fetched_timestamp(dataset.id, timestamp)
  end

  def handle_continue(:stop, state) do
    {:stop, :normal, state}
  end

  defp maybe_create_job(%SmartCity.Dataset{technical: %{cadence: cadence}} = dataset) when is_integer(cadence) do
    Reaper.Event.Handlers.DatasetUpdate.handle(dataset)
  end

  defp maybe_create_job(_dataset), do: nil

  defp find_dataset_update(reaper_config) do
    Brook.get_events!(:reaper_config, reaper_config.dataset_id)
    |> Enum.filter(fn event -> event.type == dataset_update() end)
    |> List.last()
  end
end

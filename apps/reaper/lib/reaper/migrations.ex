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

  defp migrate_reaper_config(%{dataset_id: dataset_id, cadence: cadence, sourceType: source_type})
       when cadence == "never" or source_type == "remote" do
    Brook.Test.with_event(%Brook.Event{type: "reaper_config:migration", author: "migration", data: dataset_id}, fn ->
      Brook.ViewState.delete(:reaper_config, dataset_id)
    end)
  end

  defp migrate_reaper_config(reaper_config) do
    dataset_update = find_dataset_update(reaper_config)
    dataset = dataset_update.data |> fix_dataset()
    last_fetched_timestamp = Persistence.get_last_fetched_timestamp(dataset.id)

    Brook.Test.with_event(%{dataset_update | data: dataset}, fn ->
      setup_view_state(dataset, last_fetched_timestamp)
      maybe_create_job(dataset)

      commands = [
        ["RENAME", "reaper:view:reaper_config:#{dataset.id}", "old:reaper:view:reaper_config:#{dataset.id}"],
        ["EXPIRE", "old:reaper:view:reaper_config:#{dataset.id}", "600000"],
        [
          "RENAME",
          "reaper:view:reaper_config:#{dataset.id}:events",
          "old:reaper:view:reaper_config:#{dataset.id}:events"
        ],
        ["EXPIRE", "old:reaper:view:reaper_config:#{dataset.id}:events", "600000"],
        ["RENAME", "reaper:derived:#{dataset.id}", "old:reaper:derived:#{dataset.id}"],
        ["EXPIRE", "old:reaper:derived:#{dataset.id}", "600000"]
      ]

      Redix.pipeline!(:redix, commands)
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

  defp fix_dataset(%SmartCity.Dataset{version: "0.4"} = dataset), do: dataset

  defp fix_dataset(%{business: business, technical: technical} = dataset) do
    {:ok, good_dataset} =
      dataset
      |> Map.from_struct()
      |> Map.put(:technical, Map.from_struct(technical))
      |> Map.put(:business, Map.from_struct(business))
      |> SmartCity.Dataset.new()

    good_dataset
  end
end

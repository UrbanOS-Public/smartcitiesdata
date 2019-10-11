defmodule Forklift.Migrations do
  @moduledoc """
  Handle forklift view state migrations
  """
  use GenServer, restart: :transient

  require Logger
  import SmartCity.Event, only: [data_ingest_start: 0]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(_opts) do
    Logger.info("#{__MODULE__}: Beginning forklift migration")
    {:ok, pid} = start_brook()

    migrate_datasets_to_process()

    stop_brook(pid)
    Logger.info("#{__MODULE__}: forklift migration completed")
    {:ok, :ok, {:continue, :stop}}
  end

  defp migrate_datasets_to_process() do
    Brook.get_all!(:migration, :datasets_to_process)
    |> Enum.map(fn {key, value} -> %{key: key, old: value} end)
    |> Enum.map(fn %{key: key} = entry -> Map.put(entry, :dataset, get_dataset(key)) end)
    |> Enum.map(fn %{key: key} = entry -> Map.put(entry, :events, get_events(key)) end)
    |> Enum.each(&add_entry/1)

    rename_old_entries()
  end

  defp add_entry(entry) do
    Enum.each(entry.events, fn event ->
      Brook.Test.with_event(:migration, event, fn ->
        Brook.ViewState.merge(:datasets, entry.dataset.id, entry.dataset)
      end)
    end)
  end

  defp get_dataset(id) do
    get_events(id)
    |> Enum.filter(fn event -> event.type == data_ingest_start() end)
    |> List.last()
    |> Map.get(:data)
  end

  defp get_events(id) do
    Brook.get_events!(:migration, :datasets_to_process, id)
  end

  defp rename_old_entries() do
    client = Forklift.Application.redis_client()

    case Redix.command!(client, ["KEYS", "forklift:view:*:datasets_to_process:*"]) do
      [] ->
        :ok

      keys ->
        commands =
          Enum.reduce(keys, [], fn key, acc ->
            acc ++
              [
                ["RENAME", key, "old:" <> key],
                ["EXPIRE", "old:" <> key, "600000"]
              ]
          end)

        Redix.pipeline!(client, commands)
    end
  end

  defp start_brook() do
    brook_config =
      Application.get_env(:forklift, :brook)
      |> Keyword.delete(:driver)
      |> Keyword.put(:instance, :migration)

    Brook.start_link(brook_config)
  end

  defp stop_brook(pid) do
    Process.unlink(pid)
    Supervisor.stop(pid)
  end

  def handle_continue(:stop, state) do
    {:stop, :normal, state}
  end
end

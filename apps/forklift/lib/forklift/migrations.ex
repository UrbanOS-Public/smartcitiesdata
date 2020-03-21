defmodule Forklift.Migrations do
  @moduledoc """
  Contains all migrations that run during startup.
  """
  require Logger
  use GenServer, restart: :transient

  import Forklift, only: [instance_name: 0]

  @instance instance_name()

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    migrate_once("last_insert_date_migration_completed", "migration:last_insert_date:start")

    {:ok, :ok, {:continue, :stop}}
  end

  def handle_continue(:stop, state) do
    {:stop, :normal, state}
  end

  def migrate_once(completed_flag_name, event_name) do
    if complete?(completed_flag_name) do
      Logger.info("Migration already completed for " <> event_name)
    else
      Logger.info("Running migration for " <> event_name)
      Brook.Event.send(@instance, event_name, :forklift, %{})
    end
  end

  defp complete?(completed_flag_name) do
    Brook.get!(@instance, :migration, completed_flag_name)
  end
end

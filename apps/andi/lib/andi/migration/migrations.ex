defmodule Andi.Migration.Migrations do
  @moduledoc """
  Contains all migrations that run during bootup.
  """
  use GenServer, restart: :transient

  @instance_name Andi.instance_name()

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    migrate_once("modified_date_migration_completed", "migration:modified_date:start")

    {:ok, :ok, {:continue, :stop}}
  end

  def handle_continue(:stop, state) do
    {:stop, :normal, state}
  end

  def migrate_once(completed_flag_name, event_name) do
    get_completed_flag(completed_flag_name)
    |> send_brook_event(event_name)
  end

  defp get_completed_flag(completed_flag_name) do
    Brook.get!(@instance_name, :migration, completed_flag_name)
  end

  defp send_brook_event(nil, event_name), do: Brook.Event.send(@instance_name, event_name, :andi, %{})

  defp send_brook_event(_completed_flag, _event_name), do: nil
end

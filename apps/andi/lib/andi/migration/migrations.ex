defmodule Andi.Migration.Migrations do
  @moduledoc """
  Contains all migrations that run during bootup.
  """
  use GenServer, restart: :transient

  import Andi, only: [instance_name: 0]

  @instance Andi.instance_name()

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    migrate_modified_dates()

    {:ok, :ok, {:continue, :stop}}
  end

  def handle_continue(:stop, state) do
    {:stop, :normal, state}
  end

  def migrate_modified_dates do
    has_migration_run?("modified_date_migration_completed")
    |> migrate_modified_dates()
  end

  defp has_migration_run?(migration_name) do
    Brook.get!(@instance, :migration, migration_name)
  end

  defp migrate_modified_dates(nil), do: Brook.Event.send(@instance, "migration:modified_dates", :andi, %{})

  defp migrate_modified_dates(_), do: nil
end

defmodule Andi.Migrations do
  @moduledoc """
  Contains all migrations that run during bootup.
  """
  use GenServer, restart: :transient

  require Andi

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
    if is_nil(Brook.get!(@instance, :migration, "modified_date_migration")) do
      Brook.Event.send(@instance, "migration:modified_dates", :andi, %{})
    end
  end
end

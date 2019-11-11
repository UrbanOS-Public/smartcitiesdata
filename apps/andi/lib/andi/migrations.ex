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
    # {:ok, brook} = start_brook()

    migrate_modified_dates()

    # stop_brook(brook)

    {:ok, :ok, {:continue, :stop}}
  end

  def handle_continue(:stop, state) do
    IO.puts("Handle continue")
    {:stop, :normal, state}
  end

  defp start_brook() do
    brook_config =
      Application.get_env(:reaper, :brook)
      |> Keyword.put(:instance, @instance)
      |> Keyword.delete(:driver)

    Brook.start_link(brook_config)
  end

  defp stop_brook(brook) do
    Process.unlink(brook)
    Supervisor.stop(brook)
  end

  def migrate_modified_dates do
    IO.puts("Starting migration modified dates")

    if is_nil(Brook.get!(@instance, :migration, "modified_date_migration")) do
      IO.puts("Modified migration needs to run")
      Brook.Event.send(@instance, "migration:modified_dates", :andi, %{})
      IO.puts("Sent migration event")
    end
  end
end

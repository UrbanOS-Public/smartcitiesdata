defmodule Reaper.Migrations do
  @moduledoc """
  Contains all migrations that run during bootup.
  """
  use GenServer, restart: :transient

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    {:ok, brook} = start_brook()

    migrate_enabled_flag()

    stop_brook(brook)

    {:ok, :ok, {:continue, :stop}}
  end

  defp start_brook() do
    brook_config = Application.get_env(:reaper, :brook) |> Keyword.delete(:driver)
    Brook.start_link(brook_config)
  end

  defp stop_brook(brook) do
    Process.unlink(brook)
    Supervisor.stop(brook)
  end

  def handle_continue(:stop, state) do
    {:stop, :normal, state}
  end

  defp migrate_enabled_flag() do
    Brook.get_all_values!(:extractions)
    |> Enum.each(&migrate_extractions/1)
  end

  defp migrate_extractions(%{enabled: _enabled}) do
    Logger.info("Nothing to migrate")
  end

  defp migrate_extractions(%{dataset: %{id: dataset_id}}) do
    Brook.Test.with_event(%Brook.Event{type: "reaper_config:migration", author: "migration", data: dataset_id}, fn ->
      Brook.ViewState.merge(:extractions, dataset_id, %{enabled: true})
    end)
  end

  defp migrate_extractions(_dataset) do
    Logger.info("Nothing to migrate")
  end
end

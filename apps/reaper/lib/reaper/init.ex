defmodule Reaper.Init do
  @moduledoc """
  Task to initialize reaper and send all reaper configs to the config server
  """
  use Task, restart: :transient

  alias Reaper.ConfigServer

  def start_link(_opts) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    Brook.get_all_values!(:reaper_config)
    |> Enum.each(&ConfigServer.process_reaper_config/1)
  end
end

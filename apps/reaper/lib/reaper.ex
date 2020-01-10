defmodule Reaper do
  @moduledoc false

  # Change Reaper

  def currently_running_jobs() do
    Reaper.Horde.Registry.get_all()
  end
end

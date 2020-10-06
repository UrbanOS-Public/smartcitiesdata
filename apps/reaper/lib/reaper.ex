defmodule Reaper do
  @moduledoc false

  def instance_name(), do: :reaper_brook

  def currently_running_jobs() do
    Reaper.Horde.Registry.get_all()
  end
end

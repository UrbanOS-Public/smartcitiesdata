defmodule Odo.Init do
  @moduledoc """
  Starts a supervisable task at application boot time
  that retrieves all outstanding file_conversion entries
  from the app state and schedules them for processing.
  """

  use Task, restart: :transient

  def start_link(_arg) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run(_arg) do
    Brook.get_all_values!(:file_conversions)
    |> Enum.each(&Odo.FileProcessor.process/1)
  end
end

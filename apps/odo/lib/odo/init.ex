defmodule Odo.Init do
  @moduledoc """
  Starts a supervisable task at application boot time
  that retrieves all outstanding file_conversion entries
  from the app state and schedules them for processing.
  """
  require Logger
  use Task, restart: :transient

  @instance_name Odo.instance_name()

  def start_link(_arg) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    pending_conversions =
      Brook.get_all_values!(@instance_name, :file_conversions)
      |> Enum.map(&Odo.ConversionMap.generate/1)
      |> Enum.map(&unwrap_ok/1)

    pending_ids = Enum.map(pending_conversions, fn file -> file.dataset_id end)

    Logger.debug("Starting file processor task for files pending conversion: #{inspect(pending_ids)}")

    Enum.each(pending_conversions, &Odo.FileProcessor.process/1)
  end

  defp unwrap_ok({:ok, value}), do: value
end

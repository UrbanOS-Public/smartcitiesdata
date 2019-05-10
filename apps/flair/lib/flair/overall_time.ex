defmodule Flair.OverallTime do
  @moduledoc false

  alias SmartCity.Data

  @doc """
  Calculate the overall time for this data message by finding the lowest start time and the highest end time and adding that as a timing for SmartCityOS with label EndToEnd
  """
  def add(%Data{operational: %{timing: []}} = msg), do: msg

  def add(%Data{operational: %{timing: timings}} = msg) do
    first_start = Enum.min_by(timings, &extract_value_as_epoch(&1, :start_time))
    last_end = Enum.max_by(timings, &extract_value_as_epoch(&1, :end_time))

    new_timing =
      Data.Timing.new("SmartCityOS", "EndToEnd", first_start.start_time, last_end.end_time)

    Data.add_timing(msg, new_timing)
  end

  defp extract_value_as_epoch(timing, key) do
    timing
    |> Map.get(key)
    |> DateTime.from_iso8601()
    |> case do
      {:ok, date, 0} -> date
    end
    |> DateTime.to_unix(:millisecond)
  end
end

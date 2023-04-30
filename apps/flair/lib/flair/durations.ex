defmodule Flair.Durations do
  @moduledoc """
  Calculate durations.
  This is done first by reducing multiple data messages to an accumulater,
  and then second by calculating the durations for those aggregate metrics.
  """

  alias SmartCity.Data

  @doc """
  Aggregates data messages into a mapping of dataset ids to timing data lists.
  """
  @spec reducer(Data.t(), map()) :: %{String.t() => [SmartCity.Data.Timing.t()]}
  def reducer(%Data{dataset_ids: ids, operational: %{timing: timing}}, outer_acc) do
    Enum.reduce(ids, outer_acc, fn id, inner_acc ->
      Map.update(inner_acc, id, List.wrap(timing), fn x ->
        timing ++ x
      end)
    end)
  end

  @doc """
  Converts raw individual timing metrics into aggregated timing statistics by app and label.
  """
  @spec calculate_durations({String.t(), map()}) :: {String.t(), map()}
  def calculate_durations({dataset_id, raw_metrics}) do
    calculated_metrics =
      raw_metrics
      |> Enum.group_by(&durations_key_fn/1, &durations_val_fn/1)
      |> Enum.map(&get_durations/1)
      |> Enum.into(Map.new())

    {dataset_id, calculated_metrics}
  end

  defp durations_key_fn(%{app: app, label: label}), do: {app, label}

  defp durations_val_fn(%{start_time: start_time, end_time: end_time}) do
    {:ok, start_time, 0} = DateTime.from_iso8601(start_time)
    {:ok, end_time, 0} = DateTime.from_iso8601(end_time)

    DateTime.diff(end_time, start_time, :millisecond)
  end

  defp get_durations({key, durations}) do
    {key,
     %{
       count: length(durations),
       max: Enum.max(durations),
       min: Enum.min(durations),
       average: Enum.sum(durations) / length(durations),
       stdev: Statistics.stdev(durations)
     }}
  end
end

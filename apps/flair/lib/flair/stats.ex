defmodule Flair.Stats do
  @moduledoc false

  alias SmartCity.Data

  def reducer(%Data{dataset_id: id, operational: %{timing: timing}}, acc) do
    Map.update(acc, id, List.wrap(timing), fn x ->
      timing ++ x
    end)
  end

  def calculate_stats({dataset_id, raw_metrics}) do
    calculated_metrics =
      raw_metrics
      |> Enum.group_by(&stats_key_fn/1, &stats_val_fn/1)
      |> Enum.map(&get_stats/1)
      |> Enum.into(Map.new())

    {dataset_id, calculated_metrics}
  end

  defp stats_key_fn(%{app: app, label: label}), do: {app, label}

  defp stats_val_fn(%{start_time: start_time, end_time: end_time}) do
    {:ok, start_time, 0} = DateTime.from_iso8601(start_time)
    {:ok, end_time, 0} = DateTime.from_iso8601(end_time)

    DateTime.diff(end_time, start_time, :millisecond)
  end

  defp get_stats({key, durations}) do
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

defmodule Forklift.DataWriter.Metric do
  @moduledoc "TODO"

  require Logger

  @collector Application.get_env(:forklift, :collector)
  @metric_name "dataset_compaction_duration_total"

  @spec record(integer(), String.t()) :: :ok | {:error, term()}
  def record(duration, table) do
    @collector.count_metric(@metric_name, [{"system_name", table}], [], DateTime.utc_now())
    |> List.wrap()
    |> @collector.record_metrics("forklift")
    |> case do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warn("Unable to write metrics for #{table}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

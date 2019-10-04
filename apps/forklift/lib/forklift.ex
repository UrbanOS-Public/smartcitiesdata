defmodule Forklift do
  @moduledoc """
  Main business logic of Forklift. Writes batches of messages to PrestoDB.
  """
  use Retry

  alias SmartCity.{Data, Dataset}
  alias Forklift.Util

  @table_writer Application.get_env(:forklift, :table_writer)
  @max_wait_time 1_000 * 60 * 60

  @spec handle_batch([%Data{}], %Dataset{}) :: :ok
  def handle_batch(batch, dataset) do
    batch
    |> Enum.map(&add_start_time/1)
    |> persist_data(dataset)
    |> Enum.map(&add_total_timing/1)
  end

  defp add_start_time(datum) do
    Util.add_to_metadata(datum, :forklift_start_time, Data.Timing.current_time())
  end

  defp persist_data(data, %Dataset{} = dataset) do
    payloads = Enum.map(data, fn datum -> datum.payload end)

    retry with: exponential_backoff(100) |> cap(@max_wait_time) do
      @table_writer.write(payloads, table: dataset.technical.systemName, schema: dataset.technical.schema)
    after
      {:ok, timing} -> Enum.map(data, &Data.add_timing(&1, timing))
    else
      {:error, reason} -> raise reason
    end
  end

  defp add_total_timing(datum) do
    start_time = datum._metadata.forklift_start_time
    timing = Data.Timing.new("forklift", "total_time", start_time, Data.Timing.current_time())

    datum
    |> Data.add_timing(timing)
    |> Util.remove_from_metadata(:forklift_start_time)
  end
end

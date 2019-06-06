defmodule Forklift do
  @moduledoc """
  Main business logic of Forklift. Writes batches of messages to PrestoDB.
  """
  use Retry
  alias SmartCity.Data
  alias SmartCity.Data.Timing
  alias Forklift.Util
  @max_wait_time 1_000 * 60 * 60

  @spec handle_batch(list(%Data{})) :: :ok | no_return()
  def handle_batch(batch) do
    batch
    |> Enum.map(&add_start_time/1)
    |> persist_data()
    |> Enum.map(&add_total_timing/1)
  end

  defp add_start_time(datum) do
    Util.add_to_metadata(datum, :forklift_start_time, Timing.current_time())
  end

  defp persist_data(data) do
    dataset_id = List.first(data).dataset_id
    payloads = Enum.map(data, fn datum -> datum.payload end)

    retry with: exponential_backoff(100) |> cap(@max_wait_time) do
      Forklift.Messages.PersistenceClient.upload_data(dataset_id, payloads)
    after
      {:ok, timing} -> Enum.map(data, &Data.add_timing(&1, timing))
    else
      {:error, reason} -> raise reason
    end
  end

  defp add_total_timing(datum) do
    start_time = datum._metadata.forklift_start_time
    timing = Timing.new("forklift", "total_time", start_time, Timing.current_time())

    datum
    |> Data.add_timing(timing)
    |> Util.remove_from_metadata(:forklift_start_time)
  end
end

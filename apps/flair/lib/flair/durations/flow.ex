defmodule Flair.Durations.Flow do
  @moduledoc """
  This flow takes in messages from the producer that it starts.
  It aggregates those messages per dataset/per window and then calculates their durations, finally persisting them.
  """
  require Logger

  use Flow

  alias SmartCity.Data

  alias Flair.Durations
  alias Flair.OverallTime

  @window_length Application.get_env(:flair, :window_length, 5)
  @window_unit Application.get_env(:flair, :window_unit, :minute)

  def start_link(_) do
    consumer_spec = [
      {
        {Flair.Durations.Consumer, :durations_consumer},
        []
      }
    ]

    [{Flair.Producer, :durations}]
    |> Flow.from_specs()
    |> Flow.map(&get_message/1)
    |> Flow.map(&OverallTime.add/1)
    |> Flow.each(&log_message/1)
    |> partition_by_dataset_id_and_window()
    |> aggregate_by_dataset()
    |> Flow.map(&Durations.calculate_durations/1)
    |> Flow.each(&log_profile/1)
    |> Flow.into_specs(consumer_spec)
  end

  defp log_message(message) do
    Logger.debug(fn -> "Received durations message: #{inspect(message)}" end)
  end

  defp log_profile(profile) do
    Logger.debug(fn -> "Calculated durations profile: #{inspect(profile)}" end)
  end

  defp partition_by_dataset_id_and_window(flow) do
    window = Flow.Window.periodic(@window_length, @window_unit)
    key_fn = &extract_id/1

    Flow.partition(flow, key: key_fn, window: window)
  end

  defp aggregate_by_dataset(flow) do
    Flow.reduce(flow, fn -> %{} end, &Durations.reducer/2)
  end

  defp get_message(kafka_msg) do
    kafka_msg
    |> Map.get(:value)
    |> Data.new()
    |> ok()
  end

  defp extract_id(%Data{dataset_ids: ids}), do: Enum.reduce(ids, "", fn id, acc -> acc <> id end)

  defp ok({:ok, data}), do: data
end

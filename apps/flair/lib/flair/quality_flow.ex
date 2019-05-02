defmodule Flair.QualityFlow do
  @moduledoc """
  This flow takes in messages from the producer that it starts. It aggregates those messages per dataset/per window and then calculates their data quality, finally persisting them.
  """
  use Flow

  alias SmartCity.Data

  alias Flair.Quality
  require Logger

  @window_length Application.get_env(:flair, :window_length, 5)
  @window_unit Application.get_env(:flair, :window_unit, :minute)

  def start_link(_) do
    consumer_spec = [
      {
        {Flair.Consumer, :quality_consumer},
        []
      }
    ]

    [{Flair.Producer, :quality}]
    |> Flow.from_specs()
    |> Flow.map(&get_message/1)
    |> Flow.each(&log_message/1)
    |> partition_by_dataset_id_and_window()
    |> aggregate_by_dataset()
    |> Flow.map(&Quality.calculate_quality/1)
    |> Flow.reject(fn record -> record == nil end)
    |> Flow.each(&log_profile/1)
    |> Flow.into_specs(consumer_spec)
  end

  defp log_message(message) do
    Logger.debug("Received quality message: #{inspect(message)}")
  end

  defp log_profile(profile) do
    Logger.info("Calculated quality profile: #{inspect(profile)}")
  end

  defp partition_by_dataset_id_and_window(flow) do
    window = Flow.Window.periodic(@window_length, @window_unit)
    key_fn = &extract_id/1

    Flow.partition(flow, key: key_fn, window: window)
  end

  defp aggregate_by_dataset(flow) do
    Flow.reduce(
      flow,
      fn -> %{window_start: DateTime.to_iso8601(DateTime.utc_now())} end,
      &Quality.reducer/2
    )
  end

  defp get_message(kafka_msg) do
    kafka_msg
    |> Map.get(:value)
    |> Data.new()
    |> ok()
  end

  defp extract_id(%Data{dataset_id: id}), do: id

  defp ok({:ok, data}), do: data
end

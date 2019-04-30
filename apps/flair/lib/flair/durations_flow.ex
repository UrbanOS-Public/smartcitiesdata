defmodule Flair.DurationsFlow do
  @moduledoc """
  This flow takes in messages from the producer that it starts. It aggregates those messages per dataset/per window and then calculates their durations, finally persisting them.
  """
  use Flow

  alias SmartCity.Data

  alias Flair.Durations
  require Logger

  @window_length Application.get_env(:flair, :window_length, 5)
  @window_unit Application.get_env(:flair, :window_unit, :minute)

  def start_link(_) do
    consumer_spec = [
      {
        {Flair.Consumer, :durations_consumer},
        []
      }
    ]

    [{Flair.Producer, :durations}]
    |> Flow.from_specs()
    |> Flow.map(&get_message/1)
    |> Flow.reject(&is_dead_letter/1)
    |> Flow.each(&log_message/1)
    |> partition_by_dataset_id_and_window()
    |> aggregate_by_dataset()
    |> Flow.map(&Durations.calculate_durations/1)
    |> Flow.each(&log_profile/1)
    |> Flow.into_specs(consumer_spec)
  end

  defp log_profile(profile) do
    Logger.info("Calculated profile: #{inspect(profile)}")
  end

  defp log_message(message) do
    Logger.info("Received message: #{inspect(message)}")
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
    try do
      kafka_msg
      |> Map.get(:value)
      |> Data.new()
      |> ok()
    rescue
      e ->
        Logger.error(
          "Dead Message Encountered: #{inspect(kafka_msg)}. Rejecting because: #{inspect(e)}"
        )

        kafka_msg
        |> Map.from_struct()
        |> Yeet.process_dead_letter("flair", error_code: e)

        :dead_letter
    end
  end

  defp is_dead_letter(message) do
    message == :dead_letter
  end

  defp extract_id(%Data{dataset_id: id}), do: id

  defp ok({:ok, data}), do: data
end

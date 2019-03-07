defmodule Flair.StatsFlow do
  @moduledoc false
  use Flow

  alias SCOS.DataMessage

  alias Flair.Stats

  @window_length Application.get_env(:flair, :window_length, 5)
  @window_unit Application.get_env(:flair, :window_unit, :minute)

  def start_link(_) do
    consumer_spec = [
      {
        {Flair.Consumer, []},
        []
      }
    ]

    [{Flair.Producer, []}]
    |> Flow.from_specs()
    |> Flow.map(&get_message/1)
    |> partition_by_dataset_id_and_window()
    |> aggregate_by_dataset()
    |> Flow.map(&Stats.calculate_stats/1)
    |> Flow.into_specs(consumer_spec)
  end

  defp partition_by_dataset_id_and_window(flow) do
    window = Flow.Window.periodic(@window_length, @window_unit)
    key_fn = &extract_id/1

    Flow.partition(flow, key: key_fn, window: window)
  end

  defp aggregate_by_dataset(flow) do
    Flow.reduce(flow, fn -> %{} end, &Stats.reducer/2)
  end

  defp get_message(kafka_msg) do
    kafka_msg
    |> Map.get(:value)
    |> DataMessage.parse_message()
  end

  defp extract_id(%DataMessage{dataset_id: id}), do: id
end

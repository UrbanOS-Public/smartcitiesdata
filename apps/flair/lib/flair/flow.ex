defmodule Flair.Flow do
  use Flow

  alias SCOS.DataMessage

  # defmodule Stats do
  #   def make_stats(msg) do
  #   end

  #   def merge_stats(stats, msg) do
  #     %{
  #       all_values: [msg.value | stats.all_values],
  #       max: max(msg.value, second)
  #     }
  #   end
  # end

  def start_link(_) do
    Flow.from_specs([{Flair.Producer, []}])
    |> Flow.map(&get_message/1)
    |> Flow.partition(key: &extract_id/1, window: Flow.Window.periodic(15, :second))
    |> Flow.reduce(fn -> %{} end, &reducer/2)
    |> Flow.map(&calculate_stats/1)
    |> Flow.map(&IO.inspect(&1, label: "#{inspect(self())} STAT RESULTS"))
    |> Flow.start_link()
  end

  defp get_message(kafka_msg) do
    kafka_msg
    |> Map.get(:value)
    |> DataMessage.parse_message()
  end

  defp extract_id(%DataMessage{metadata: %{id: id}}) do
    id
  end

  defp merge_maps(
         _key,
         %{duration: d1, start_time: s1} = _map1,
         %{duration: d2, start_time: s2} = _map2
       ) do
    %{
      duration: [d2 | List.wrap(d1)],
      start_time: [s2 | List.wrap(s1)]
    }
  end

  defp reducer(%DataMessage{operational: operational} = msg, acc) do
    # Map.update(acc, extract_id(msg), [operational], &[operational | &1])
    Map.update(acc, extract_id(msg), operational, fn x ->
      Map.merge(x, operational, &merge_maps/3)
    end)
  end

  defp calculate_stats({key, stats}) do
    value =
      stats
      |> Enum.map(fn {app, app_stats} ->
        {app, get_stats(app_stats)}
      end)
      |> Enum.into(Map.new())

    {key, value}
  end

  defp get_stats(dataset_stats) do
    durations = Map.get(dataset_stats, :duration)

    %{
      count: length(durations),
      max: Enum.max(durations),
      min: Enum.min(durations),
      average: Enum.sum(durations) / length(durations),
      stdev: Statistics.stdev(durations)
    }
  end
end

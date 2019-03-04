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
    consumer_spec = [
      {
        {Flair.Consumer, []},
        []
      }
    ]

    Flow.from_specs([{Flair.Producer, []}])
    |> Flow.map(&get_message/1)
    |> Flow.partition(key: &extract_id/1, window: Flow.Window.periodic(15, :second))
    |> Flow.reduce(fn -> %{} end, &reducer/2)
    |> Flow.map(&calculate_stats/1)
    # |> Flow.merge(stages: 1, window: Flow.Window.count(5))
    # |> Flow.map(&IO.inspect(&1, label: "#{inspect(self())} STAT RESULTS"))
    |> Flow.into_specs(consumer_spec)

    # |> Flow.start_link()
  end

  defp get_message(kafka_msg) do
    kafka_msg
    |> Map.get(:value)
    |> DataMessage.parse_message()
  end

  defp extract_id(%DataMessage{dataset_id: id}) do
    id
  end

  defp reducer(%DataMessage{operational: %{timing: timing}} = msg, acc) do
    Map.update(acc, extract_id(msg), List.wrap(timing), fn x ->
      timing ++ x
    end)
  end

  defp calculate_stats({dataset_id, raw_metrics}) do
    raw_metrics
    |> Enum.group_by(
      &{&1.app, &1.label},
      &DateTime.diff(
        &1.end_time |> DateTime.from_iso8601() |> elem(1),
        &1.start_time |> DateTime.from_iso8601() |> elem(1),
        :millisecond
      )
    )
    |> Enum.map(&get_stats/1)
    |> Enum.into(Map.new())
    |> (&{dataset_id, &1}).()
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

# {4,
#  %{
#    {"valkyrie", "placeholder_stat"} => %{
#      average: 471472.22222222225,
#      count: 36,
#      max: 983000,
#      min: 3000,
#      stdev: 313451.1734182598
#    }
#  }}

# defp do_stuff({dataset_id, stats_map}) do
#   stats_map
#   |> Enum.map(fn stats ->
#     nil
#   end)
# end

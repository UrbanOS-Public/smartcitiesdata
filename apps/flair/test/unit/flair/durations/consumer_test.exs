defmodule Flair.ConsumerTest do
  use ExUnit.Case

  import Mox

  setup :verify_on_exit!

  describe "handle_events/3" do
    test "properly converts duration events" do
      events = durations_events_input()
      expected = durations_events_output()

      expect(MockTableWriter, :write, fn actual, _ ->
        payloads =
          Enum.map(actual, fn %{payload: content} ->
            %{payload: Map.delete(content, "timestamp")}
          end)

        assert payloads == expected
      end)

      Flair.Durations.Consumer.handle_events(events, nil, nil)
    end
  end

  defp durations_events_input() do
    [
      {"123",
       %{
         {"reaper", "json_decode"} => %{
           average: 1_579_666.6666666667,
           count: 3,
           max: 3_058_000,
           min: 318_000,
           stdev: 1_129_043.3511999834
         }
       }},
      {"456",
       %{
         {"valkyrie", "operation"} => %{
           average: 1.2,
           count: 3,
           max: 10,
           min: 3,
           stdev: 123.4321
         }
       }}
    ]
  end

  defp durations_events_output() do
    [
      %{
        payload: %{
          "app" => "reaper",
          "dataset_id" => "123",
          "label" => "json_decode",
          "stats" => %{
            average: 1_579_666.6666666667,
            count: 3,
            max: 3_058_000,
            min: 318_000,
            stdev: 1_129_043.3511999834
          }
        }
      },
      %{
        payload: %{
          "app" => "valkyrie",
          "dataset_id" => "456",
          "label" => "operation",
          "stats" => %{
            average: 1.2,
            count: 3,
            max: 10,
            min: 3,
            stdev: 123.4321
          }
        }
      }
    ]
  end
end

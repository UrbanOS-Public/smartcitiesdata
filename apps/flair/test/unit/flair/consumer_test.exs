defmodule Flair.ConsumerTest do
  use ExUnit.Case
  use Placebo

  describe "handle_events/3" do
    test "properly converts quality events" do
      events = quality_events_input()
      expected = quality_events_output()

      allow(Flair.PrestoClient.generate_statement_from_events(any()), return: :ok)
      allow(Flair.PrestoClient.execute(any()), return: :ok)

      Flair.Consumer.handle_events(events, nil, nil)
      assert_called(Flair.PrestoClient.generate_statement_from_events(expected))
    end

    test "properly converts duration events" do
      events = durations_events_input()
      expected = durations_events_output()

      allow(Flair.PrestoClient.generate_statement_from_events(any()), return: :ok)
      allow(Flair.PrestoClient.execute(any()), return: :ok)

      Flair.Consumer.handle_events(events, nil, nil)
      assert_called(Flair.PrestoClient.generate_statement_from_events(expected))
    end
  end

  defp quality_events_input() do
    [
      {"abc",
       [
         %{
           dataset_id: "abc",
           schema_version: "0.1",
           field: "fun time",
           window_start: "abc",
           window_end: "xyz",
           valid_values: 5,
           records: 5
         },
         %{
           dataset_id: "abc",
           schema_version: "0.1",
           field: "happy",
           window_start: "abc",
           window_end: "xyz",
           valid_values: 4,
           records: 5
         }
       ]},
      {"456",
       [
         %{
           dataset_id: "456",
           schema_version: "0.1",
           field: "id",
           window_start: "456",
           window_end: "xyz",
           valid_values: 1,
           records: 5
         }
       ]}
    ]
  end

  defp quality_events_output() do
    [
      %{
        dataset_id: "abc",
        schema_version: "0.1",
        field: "fun time",
        window_start: "abc",
        window_end: "xyz",
        valid_values: 5,
        records: 5
      },
      %{
        dataset_id: "abc",
        schema_version: "0.1",
        field: "happy",
        window_start: "abc",
        window_end: "xyz",
        valid_values: 4,
        records: 5
      },
      %{
        dataset_id: "456",
        schema_version: "0.1",
        field: "id",
        window_start: "456",
        window_end: "xyz",
        valid_values: 1,
        records: 5
      }
    ]
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
        app: "reaper",
        dataset_id: "123",
        label: "json_decode",
        stats: %{
          average: 1_579_666.6666666667,
          count: 3,
          max: 3_058_000,
          min: 318_000,
          stdev: 1_129_043.3511999834
        },
        timestamp: any()
      },
      %{
        app: "valkyrie",
        dataset_id: "456",
        label: "operation",
        stats: %{
          average: 1.2,
          count: 3,
          max: 10,
          min: 3,
          stdev: 123.4321
        },
        timestamp: any()
      }
    ]
  end
end

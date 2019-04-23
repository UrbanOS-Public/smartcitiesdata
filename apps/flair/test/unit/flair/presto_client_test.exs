defmodule Flair.PrestoClientTest do
  use ExUnit.Case
  alias Flair.PrestoClient

  # Make config properties
  @table_name_timing "operational_stats"
  @table_name_quality "dataset_quality"

  describe "create_insert_statement" do
    setup do
      {:ok, %{time: get_time(), end_time: get_time_end()}}
    end

    test "timing table", %{time: timestamp} do
      events = [
        %{
          dataset_id: "abc",
          app: "app_1",
          label: "label_1",
          timestamp: timestamp,
          stats: %{count: 2, min: 1, max: 2, stdev: 0.7, average: 1.5}
        },
        %{
          dataset_id: "abc",
          app: "app_1",
          label: "label_2",
          timestamp: timestamp,
          stats: %{count: 2, min: 2, max: 3, stdev: 0.7, average: 2.5}
        }
      ]

      assert "INSERT INTO #{@table_name_timing()} VALUES ('abc', 'app_1', 'label_1', #{timestamp}, row(2,1,2,0.7,1.5)), ('abc', 'app_1', 'label_2', #{
               timestamp
             }, row(2,2,3,0.7,2.5))" ==
               PrestoClient.generate_statement_from_events(events)
    end

    test "quality table", %{time: timestamp, end_time: end_time} do
      events = [
        %{
          dataset_id: "abc",
          schema_version: 1,
          field: "name",
          window_start: timestamp,
          window_end: end_time,
          valid_values: 49,
          records: 50
        },
        %{
          dataset_id: "abc",
          schema_version: 1,
          field: "id",
          window_start: timestamp,
          window_end: end_time,
          valid_values: 3,
          records: 4
        }
      ]

      assert "INSERT INTO #{@table_name_quality()} VALUES ('abc', '1', 'name', '#{timestamp}','#{
               end_time
             }', 49, 50), ('abc', '1', 'id', '#{timestamp}','#{end_time}', 3, 4)" ==
               PrestoClient.generate_statement_from_events(events)
    end
  end

  defp get_time do
    DateTime.utc_now() |> DateTime.to_unix()
  end

  defp get_time_end do
    DateTime.utc_now()
    |> DateTime.add(5, :second)
    |> DateTime.to_unix()
  end
end

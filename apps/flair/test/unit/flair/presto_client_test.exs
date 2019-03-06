defmodule Flair.PrestoClientTest do
  use ExUnit.Case

  alias Flair.PrestoClient

  describe "create_insert_statement" do
    setup do
      {:ok, %{time: get_time()}}
    end

    test "whatever", %{time: timestamp} do
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

      assert "INSERT INTO #{PrestoClient.table_name()} VALUES ('abc', 'app_1','label_1', #{
               timestamp
             }, row(2,1,2,0.7,1.5)), ('abc', 'app_1','label_2', #{timestamp}, row(2,2,3,0.7,2.5))" ==
               PrestoClient.generate_statement_from_events(events)
    end
  end

  defp get_time do
    DateTime.utc_now() |> DateTime.to_unix()
  end
end

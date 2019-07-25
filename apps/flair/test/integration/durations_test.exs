defmodule DurationsTest do
  use ExUnit.Case
  use Divo
  alias SmartCity.Data.Timing
  require Logger

  setup _ do
    messages =
      [
        %{
          "payload" => %{"name" => "Jack Sparrow"},
          "_metadata" => %{},
          "dataset_id" => "pirates",
          "operational" => %{"timing" => [timing()]}
        },
        %{
          "payload" => %{"name" => "Will Turner"},
          "_metadata" => %{},
          "dataset_id" => "pirates",
          "operational" => %{"timing" => [timing()]}
        },
        %{
          "payload" => %{"name" => "Barbosa"},
          "_metadata" => %{},
          "dataset_id" => "pirates",
          "operational" => %{"timing" => [timing()]}
        }
      ]
      |> Enum.map(&Jason.encode!/1)

    "delete from operational_stats"
    |> Prestige.execute()
    |> Prestige.prefetch()

    [messages: messages]
  end

  test "flair consumes messages and calls out to presto", context do
    SmartCity.Dataset.write(TestHelper.create_simple_dataset() |> Map.put(:id, "pirates"))

    SmartCity.KafkaHelper.send_to_kafka(
      context[:messages],
      Application.get_env(:flair, :data_topic)
    )

    Patiently.wait_for!(
      prestige_query("select dataset_id, app from operational_stats", [
        ["pirates", "SmartCityOS"],
        ["pirates", "valkyrie"]
      ]),
      dwell: 1000,
      max_tries: 20
    )
  end

  defp prestige_query(statement, expected) do
    fn ->
      actual =
        statement
        |> Prestige.execute()
        |> Prestige.prefetch()

      Logger.info("Waiting for #{inspect(actual)} to equal #{inspect(expected)}")

      try do
        assert actual == expected
        true
      rescue
        _ -> false
      end
    end
  end

  defp timing() do
    start_time = Timing.current_time()
    Process.sleep(1)

    %{
      "start_time" => start_time,
      "end_time" => Timing.current_time(),
      "app" => :valkyrie,
      "label" => ""
    }
  end
end

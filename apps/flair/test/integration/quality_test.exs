defmodule QualityIntegrationTest do
  use ExUnit.Case
  use Divo
  use Placebo

  require Logger

  alias SmartCity.TestDataGenerator, as: TDG

  @endpoint Application.get_env(:kaffe, :producer)[:endpoints]
            |> Enum.map(fn {k, v} -> {k, v} end)

  setup _ do
    SmartCity.Dataset.write(TestHelper.create_simple_dataset())

    data_overrides = [
      %{dataset_id: "123", payload: %{"id" => "123", "name" => "John Smith"}},
      %{dataset_id: "123", payload: %{"name" => "John Smith"}},
      %{dataset_id: "123", payload: %{"id" => "123"}}
    ]

    messages =
      data_overrides
      |> Enum.map(fn override -> TDG.create_data(override) end)
      |> Enum.map(&Jason.encode!/1)

    "delete from dataset_quality"
    |> Prestige.execute()
    |> Prestige.prefetch()

    [messages: messages]
  end

  test "flair consumes messages and calls out to presto", context do
    Mockaffe.send_to_kafka(context[:messages], "streaming-transformed")

    # Waiting for [["123", "0.1", "id", 123, 456, 0, 3]] to equal ["abc", "1", "*", "*", "*", "*"]

    Patiently.wait_for!(
      prestige_query(
        "select dataset_id, schema_version, field, window_start, window_end, valid_values, records from dataset_quality",
        [["123", "0.1", "id", 123, 456, 0, 3]]
      ),
      dwell: 1000,
      max_tries: 20
    )
  end

  # test "flair gracefully handles messages that don't parse in the standard format" do
  #   messages =
  #     [
  #       %{
  #         "payload" => %{"name" => "Jackie Chan"},
  #         "_metadata" => %{},
  #         "dataset_id" => "ninjas",
  #         "operational" => %{"timing" => [timing()]}
  #       },
  #       %{
  #         "payload" => %{"name" => "Barbosa"},
  #         "not_metadata" => %{},
  #         "dataset_id" => "notExisting",
  #         "operational" => %{"timing" => [timing()]}
  #       }
  #     ]
  #     |> Enum.map(&Jason.encode!/1)

  #   Mockaffe.send_to_kafka(messages, "streaming-transformed")

  #   Patiently.wait_for!(
  #     prestige_query("select dataset_id, app from operational_stats", [
  #       ["ninjas", "valkyrie"]
  #     ]),
  #     dwell: 1000,
  #     max_tries: 20
  #   )
  # end

  # test "should insert records into Presto", context do
  #   Mockaffe.send_to_kafka(context[:messages], "streaming-transformed")

  #   Patiently.wait_for!(
  #     prestige_query("select dataset_id, app from operational_stats", [
  #       ["pirates", "valkyrie"]
  #     ]),
  #     dwell: 1000,
  #     max_tries: 20
  #   )
  # end

  # test "should send errors to DLQ", context do
  #   messages =
  #     [
  #       %{
  #         "payload" => %{"name" => "Barbosa"},
  #         "metadata" => %{},
  #         "dataset_id" => "pirates",
  #         "operational" => %{"timing" => [timing()]}
  #       }
  #     ]
  #     |> Enum.map(&Jason.encode!/1)

  #   Mockaffe.send_to_kafka(messages, "streaming-transformed")

  #   get_dead_letter = fn ->
  #     fetch_and_unwrap("streaming-dead-letters")
  #     |> Enum.any?()
  #   end

  #   Patiently.wait_for!(
  #     get_dead_letter,
  #     dwell: 1000,
  #     max_tries: 20
  #   )
  # end

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

  defp fetch_and_unwrap(topic) do
    {:ok, messages} = :brod.fetch(@endpoint, topic, 0, 0)

    messages
    |> Enum.map(fn {:kafka_message, _, _, _, key, body, _, _, _} -> {key, body} end)
  end
end

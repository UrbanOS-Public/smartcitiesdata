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
      %{dataset_id: "123", payload: %{"id" => "123", "name" => "John Doe"}},
      %{dataset_id: "123", payload: %{"name" => "Bob Smith"}},
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
    Mockaffe.send_to_kafka(context[:messages], Application.get_env(:flair, :data_topic))

    Patiently.wait_for!(
      fn ->
        actual_result =
          "select dataset_id, schema_version, field, window_start, window_end, valid_values, records from dataset_quality"
          |> Prestige.execute()
          |> Prestige.prefetch()

        try do
          actual = Enum.at(actual_result, 0)
          Logger.info("Waiting for #{inspect(actual)} to equal expected}")

          actual_start = DateTime.from_iso8601(Enum.at(actual, 3))
          actual_end = DateTime.from_iso8601(Enum.at(actual, 4))

          assert Enum.at(actual, 0) == "123" &&
                   Enum.at(actual, 1) == "0.1" &&
                   Enum.at(actual, 2) == "id" &&
                   Enum.at(actual, 5) == 2 &&
                   Enum.at(actual, 6) == 3 &&
                   actual_end > actual_start

          true
        rescue
          _ ->
            false
        end
      end,
      dwell: 1000,
      max_tries: 20
    )
  end

  test "should send errors to DLQ" do
    message =
      %{dataset_id: "NotADataset", payload: %{"id" => "NotADataset", "name" => "Fred"}}
      |> TDG.create_data()
      |> Jason.encode!()

    Mockaffe.send_to_kafka([message], Application.get_env(:flair, :data_topic))

    get_dead_letter = fn ->
      fetch_and_unwrap("streaming-dead-letters")
      |> Enum.any?()
    end

    Patiently.wait_for!(
      get_dead_letter,
      dwell: 1000,
      max_tries: 20
    )
  end

  defp fetch_and_unwrap(topic) do
    {:ok, messages} = :brod.fetch(@endpoint, topic, 0, 0)

    messages
    |> Enum.map(fn {:kafka_message, _, _, _, key, body, _, _, _} -> {key, body} end)
  end
end

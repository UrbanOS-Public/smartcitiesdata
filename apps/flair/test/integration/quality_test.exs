defmodule QualityIntegrationTest do
  use ExUnit.Case
  use Divo
  use Placebo

  require Logger

  alias SmartCity.TestDataGenerator, as: TDG

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
                   Enum.at(actual, 5) == 0 &&
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
end

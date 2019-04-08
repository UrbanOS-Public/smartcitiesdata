defmodule FlairTest do
  use ExUnit.Case
  use Divo
  use Placebo
  alias SmartCity.Data.Timing
  require Logger
  doctest Flair

  @endpoint Application.get_env(:kaffe, :producer)[:endpoints]
            |> Enum.map(fn {k, v} -> {k, v} end)

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

    [messages: messages]
  end

  test "flair consumes messages and calls out to presto", context do
    allow(Flair.PrestoClient.execute(any()), return: [])
    allow(Flair.PrestoClient.generate_statement_from_events(any()), return: "")
    Mockaffe.send_to_kafka(context[:messages], "streaming-transformed")

    Patiently.wait_for!(
      &wait_for_function_call/0,
      dwell: 1000,
      max_tries: 10
    )
  end

  test "flair gracefully handles messages that don't parse in the standard format" do
    messages =
      [
        %{
          "payload" => %{"name" => "Barbosa"},
          "metadata" => %{},
          "dataset_id" => "pirates",
          "operational" => %{"timing" => [timing()]}
        }
      ]
      |> Enum.map(&Jason.encode!/1)

    allow(Flair.PrestoClient.execute(any()), return: [])
    allow(Flair.PrestoClient.generate_statement_from_events(any()), return: "")
    Mockaffe.send_to_kafka(messages, "streaming-transformed")

    Patiently.wait_for!(
      &wait_for_function_not_called/0,
      dwell: 1000,
      max_tries: 10
    )
  end

  test "should insert records into Presto", context do
    Mockaffe.send_to_kafka(context[:messages], "streaming-transformed")

    Patiently.wait_for!(
      prestige_query("select dataset_id, app from operational_stats", [
        ["pirates", "valkyrie"]
      ]),
      dwell: 1000,
      max_tries: 20
    )
  end

  test "should send errors to DLQ", context do
    messages =
      [
        %{
          "payload" => %{"name" => "Barbosa"},
          "metadata" => %{},
          "dataset_id" => "pirates",
          "operational" => %{"timing" => [timing()]}
        }
      ]
      |> Enum.map(&Jason.encode!/1)

    allow(Flair.PrestoClient.execute(any()), return: [])
    allow(Flair.PrestoClient.generate_statement_from_events(any()), return: "")

    Mockaffe.send_to_kafka(messages, "streaming-transformed")

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

  def wait_for_function_call() do
    try do
      assert_called(
        # Figure out how to Divo a presto environment to complete the integration test environment
        Flair.PrestoClient.execute(any()),
        once()
      )

      true
    rescue
      _ -> false
    end
  end

  def wait_for_function_not_called() do
    try do
      refute_called(
        # Figure out how to Divo a presto environment to complete the integration test environment
        Flair.PrestoClient.execute(any()),
        once()
      )

      true
    rescue
      _ -> false
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

  defp fetch_and_unwrap(topic) do
    {:ok, messages} = :brod.fetch(@endpoint, topic, 0, 0)

    messages
    |> Enum.map(fn {:kafka_message, _, _, _, key, body, _, _, _} -> {key, body} end)
  end
end

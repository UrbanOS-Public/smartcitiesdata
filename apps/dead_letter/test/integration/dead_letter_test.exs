defmodule DeadLetterTest do
  use ExUnit.Case
  use Divo
  import Assertions

  test "successfully sends messages to kafka" do
    DeadLetter.process("123-456", "789-101", %{topic: "foobar", payload: "{\"key\":\"value\"}"}, "loader")

    assert_async(timeout: 1_000, sleep_wait: 100) do
      message =
        Elsa.Fetch.search_values([localhost: 9092], "dead-letters", "loader")
        |> Enum.into([])
        |> case do
          [%Elsa.Message{value: value}] ->
            Jason.decode!(value)

          [] ->
            %{"app" => nil}
        end

      assert message["app"] == "loader"
    end
  end

  test "recovers if message is undeliverable" do
    DeadLetter.process("invalid-dataset", "invalid-ingestion" "invalid-message", {"wrong"})
    DeadLetter.process("valid-dataset", "valid-ingestion", "valid-message", "normalizer")

    assert_async(timeout: 1_000, sleep_wait: 100) do
      original_messages =
        Elsa.Fetch.search_values([localhost: 9092], "dead-letters", "valid")
        |> Enum.into([])
        |> case do
          [_msg | _msgs] = messages ->
            Enum.map(messages, fn %Elsa.Message{value: value} -> Jason.decode!(value)["original_message"] end)

          [] ->
            []
        end

      refute "invalid-message" in original_messages
      assert "valid-message" in original_messages
    end
  end
end

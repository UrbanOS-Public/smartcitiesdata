defmodule DeadLetterTest do
  use ExUnit.Case
  use Divo
  import Assertions

  setup do
    config = [
      driver: [
        module: DeadLetter.Carrier.Kafka,
        init_args: [
          name: :client,
          endpoints: [localhost: 9092],
          topic: "dead-letters"
        ]
      ]
    ]

    {:ok, dlq} = DeadLetter.start_link(config)

    on_exit(fn ->
      kill_and_wait(dlq)
    end)
  end

  test "successfully sends messages to kafka" do
    DeadLetter.process("123-456", %{topic: "foobar", payload: "{\"key\":\"value\"}"}, "loader")

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
    DeadLetter.process("invalid-dataset", "invalid-message", {"wrong"})
    DeadLetter.process("valid-dataset", "valid-message", "normalizer")

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

  defp kill_and_wait(pid, timeout \\ 1_000) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    assert_receive {:DOWN, ^ref, _, _, _}, timeout
  end
end

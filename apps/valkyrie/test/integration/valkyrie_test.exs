defmodule ValkyrieTest do
  use ExUnit.Case
  use Divo

  @messages [
              %{
                "payload" => %{"name" => "Jack Sparrow"},
                "operational" => %{"ship" => "Black Pearl", "timing" => []},
                "dataset_id" => "basic",
                "_metadata" => %{}
              },
              %{
                "payload" => %{"name" => "I am bad"},
                "dataset_id" => "dlq",
                "_metadata" => %{}
              },
              %{
                "payload" => %{"name" => "Will Turner"},
                "operational" => %{"ship" => "Black Pearl", "timing" => []},
                "dataset_id" => "basic",
                "_metadata" => %{}
              },
              %{
                "payload" => %{"name" => "Barbosa"},
                "operational" => %{"ship" => "Dead Jerks", "timing" => []},
                "dataset_id" => "basic",
                "_metadata" => %{}
              }
            ]
            |> Enum.map(&Jason.encode!/1)

  @endpoint Application.get_env(:kaffe, :consumer)[:endpoints]

  test "valkyrie updates the operational struct" do
    Mockaffe.send_to_kafka(@messages, "raw")

    assert any_messages_where("validated", fn message ->
             Enum.any?(message.operational.timing, &(&1.app == "valkyrie"))
           end)
  end

  test "valkyrie does not change the content of the messages processed" do
    Mockaffe.send_to_kafka(@messages, "raw")

    assert messages_as_expected(
             "validated",
             ["Jack Sparrow", "Will Turner", "Barbosa"],
             fn message ->
               message.payload.name
             end
           )
  end

  test "valkyrie sends invalid data messages to the dlq" do
    Mockaffe.send_to_kafka(@messages, "raw")

    Patiently.wait_for!(
      fn ->
        data_messages = fetch_and_unwrap("dead-letters")

        Enum.any?(data_messages, fn data_message ->
          assert String.contains?(data_message.reason, "Invalid data message")
          assert data_message.app == "Valkyrie"
          assert String.contains?(data_message.original_message, "I am bad")
        end)
      end,
      dwell: 1000,
      max_tries: 10
    )
  end

  defp any_messages_where(topic, callback) do
    :ok ==
      Patiently.wait_for!(
        fn ->
          topic
          |> fetch_and_unwrap()
          |> Enum.any?(callback)
        end,
        dwell: 1000,
        max_tries: 10
      )
  end

  defp messages_as_expected(topic, expected, callback) do
    Patiently.wait_for!(
      fn ->
        actual =
          topic
          |> fetch_and_unwrap()
          |> Enum.map(callback)

        IO.puts("Waiting for actual #{inspect(actual)} to match expected #{inspect(expected)}")

        actual == expected
      end,
      dwell: 1000,
      max_tries: 10
    )
  end

  defp fetch_and_unwrap(topic) do
    {:ok, messages} = :brod.fetch(@endpoint, topic, 0, 0)

    messages
    |> Enum.map(fn {:kafka_message, _, _, _, key, body, _, _, _} ->
      {key, body}
    end)
    |> Enum.map(fn {_key, body} -> Jason.decode!(body, keys: :atoms) end)
  end
end

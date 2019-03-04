defmodule ValkyrieTest do
  use ExUnit.Case
  use Divo.Integration

  @endpoint Application.get_env(:kaffe, :consumer)[:endpoints]
            |> Enum.map(fn {k, v} -> {k, v} end)

  test "valkyrie reads a message off Kafka and puts it back" do
    messages =
      [
        %{
          "payload" => %{"name" => "Jack Sparrow"},
          "operational" => %{"ship" => "Black Pearl"}
        },
        %{
          "payload" => %{"name" => "Will Turner"},
          "operational" => %{"ship" => "Black Pearl"}
        },
        %{
          "payload" => %{"name" => "Barbosa"},
          "operational" => %{"ship" => "Dead Jerks"}
        }
      ]
      |> Enum.map(&Jason.encode!/1)

    Mockaffe.send_to_kafka(messages, "raw")

    Patiently.wait_for!(
      fn ->
        fetch_and_unwrap("validated")
        |> Enum.any?(fn {_key, message} ->
          valkyrie =
            message
            |> Jason.decode!()
            |> Map.get("operational")
            |> Map.get("valkyrie")

          valkyrie != nil
        end)
      end,
      dwell: 1000,
      max_tries: 10
    )
  end

  defp fetch_and_unwrap(topic) do
    {:ok, messages} = :brod.fetch(@endpoint, topic, 0, 0)

    messages
    |> Enum.map(fn {:kafka_message, _, _, _, key, body, _, _, _} -> {key, body} end)
  end
end

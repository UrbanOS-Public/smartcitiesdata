defmodule Valkyrie.TopicPerDatasetTest do
  require Logger

  use ExUnit.Case
  use Divo

  alias SmartCity.TestDataGenerator, as: TDG

  @endpoints Application.get_env(:valkyrie, :brod_brokers)
  @elsa_endpoints Application.get_env(:valkyrie, :elsa_brokers)

  import Record, only: [defrecord: 2, extract: 2]

  defrecord :kafka_message,
            extract(:kafka_message, from_lib: "kafka_protocol/include/kpro_public.hrl")

  test "DatasetHandler creates new topic on dataset message" do
    dataset =
      TDG.create_dataset(
        id: "topic-create-test",
        technical: %{schema: [%{name: "key", type: "string"}]}
      )

    SmartCity.Dataset.write(dataset)

    Patiently.wait_for!(
      fn ->
        Valkyrie.TopicManager.is_topic_ready?("raw-topic-create-test")
      end,
      dwell: 200,
      max_tries: 20
    )
  end

  test "handler reads incoming topic, validates, and writes to outgoing topic" do
    dataset =
      TDG.create_dataset(
        id: "somevalue",
        technical: %{
          schema: [
            %{
              name: "name",
              type: "map",
              subSchema: [%{name: "first", type: "string"}, %{name: "last", type: "string"}]
            }
          ]
        }
      )

    SmartCity.Dataset.write(dataset)

    Patiently.wait_for(
      fn -> Valkyrie.TopicManager.is_topic_ready?("raw-somevalue") end,
      dwell: 200,
      max_tries: 100
    )

    # Valkyrie.DatasetHandler.handle_dataset(dataset)

    message = %{
      "payload" => %{"name" => %{"first" => "  Jeff ", "last" => "Grunewald"}},
      "operational" => %{"timing" => []},
      "dataset_id" => "somevalue",
      "_metadata" => %{},
      "version" => "0.1"
    }

    Kaffe.Producer.produce_sync(
      "raw-#{dataset.id}",
      "the_key",
      Jason.encode!(message)
    )

    expected_message = {"the_key", Jason.encode!(message)}

    # Test that the stopgap producer to the old transformed topic is still working
    topic_contains("validated", expected_message)
  end

  defp topic_contains(topic, expected_message) do
    Patiently.wait_for!(
      fn ->
        topic
        |> fetch_and_unwrap()
        |> Enum.any?(fn message ->
          message == expected_message
        end)
      end,
      dwell: 1000,
      max_tries: 10
    )
  end

  defp fetch_and_unwrap(topic) do
    Enum.map(extract_messages(topic), fn {key, body} ->
      {key, body |> clear_timing() |> Jason.encode!()}
    end)
  end

  defp extract_messages(topic) do
    case :brod.fetch(@endpoints, topic, 0, 0) do
      {:ok, {_offset, messages}} ->
        messages
        |> Enum.map(fn message ->
          {kafka_message(message, :key), kafka_message(message, :value)}
        end)

      {:error, reason} ->
        Logger.warn("Failed to extract messages: #{inspect(reason)}")
        []
    end
  end

  def clear_timing(json_encoded_message) do
    json_encoded_message
    |> Jason.decode!()
    |> Map.update!("operational", fn _ -> %{timing: []} end)
  end
end

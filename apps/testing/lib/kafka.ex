defmodule Testing.Kafka do
  @moduledoc """
  Module that has helpers for working with Kafka in tests
  """

  require Elsa.Message
  require Logger

  def produce_message(message, topic, endpoints) do
    Elsa.Producer.produce(
      endpoints,
      topic,
      {"jerks", Jason.encode!(message)},
      parition: 0
    )
  end

  def produce_messages(messages, topic, endpoints) do
    Enum.each(messages, &produce_message(&1, topic, endpoints))
  end

  def fetch_messages(topic, endpoints) do
    case :brod.fetch(endpoints, topic, 0, 0) do
      {:ok, {_offset, messages}} ->
        messages
        |> Enum.map(&Elsa.Message.kafka_message(&1, :value))
        |> Enum.map(&safe_decode/1)

      {:error, reason} ->
        Logger.debug("Failed to extract messages for #{topic} from #{inspect(endpoints)}: #{inspect(reason)}")
        []
    end
  end

  defp safe_decode(value) do
    case Jason.decode(value) do
      {:ok, decoded} -> decoded
      _ -> value
    end
  end

  def fetch_messages(topic, endpoints, module) do
    fetch_messages(topic, endpoints)
    |> Enum.map(fn message ->
      case apply(module, :new, [message]) do
        {:ok, data} -> data
        _ -> message
      end
    end)
  end

  def wait_for_topic(endpoints, topic) do
    Patiently.wait_for!(
      fn ->
        found = Elsa.topic?(endpoints, topic)
        Logger.debug("Topic #{topic} found at #{inspect(endpoints)}? #{found}")
        found
      end,
      dwell: 200,
      max_tries: 50
    )
  end
end

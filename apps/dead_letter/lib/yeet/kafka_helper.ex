defmodule Yeet.KafkaHelper do
  @moduledoc """
    Helper module for sending messages to Kafka.
  """

  @doc """
  Produce sends a message to the dead_letter topic
  """
  @spec produce(any()) :: :ok | {:error, any()}
  def produce(message) do
    :brod.start_client(endpoint(), :dead_letter_client, [])
    :brod.start_producer(:dead_letter_client, topic(), [])
    :brod.produce_sync(:dead_letter_client, topic(), 0, message.app, Jason.encode!(message))
  end

  defp endpoint do
    Application.get_env(:yeet, :endpoint)
  end

  defp topic do
    Application.get_env(:yeet, :topic)
  end
end

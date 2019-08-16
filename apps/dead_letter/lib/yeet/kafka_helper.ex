defmodule Yeet.KafkaHelper do
  require Logger

  @moduledoc """
    Helper module for sending messages to Kafka.
  """

  @doc """
  Produce sends a message to the dead_letter topic
  """
  @spec produce(any()) :: :ok | {:error, any()}
  def produce(message) do
    :ok = :brod.start_client(endpoint(), :dead_letter_client, [])
    :ok = :brod.start_producer(:dead_letter_client, topic(), [])
    :ok = :brod.produce_sync(:dead_letter_client, topic(), 0, message.app, Jason.encode!(message))
  rescue
    e -> Logger.error("Unable to yeet message: #{inspect(message)}\n\treason: #{inspect(e)}")
  end

  defp endpoint do
    Application.get_env(:yeet, :endpoint)
  end

  defp topic do
    Application.get_env(:yeet, :topic)
  end
end

defmodule DeadLetter.KafkaDriver do
  require Logger

  @moduledoc """
  Helper module for sending messages to Kafka.
  """

  @doc """
  Produce sends a message to the dead_letter topic
  """
  @spec produce(any()) :: :ok | {:error, any()}
  def produce(message) do
    Elsa.Producer.produce(endpoint(), topic(), {message.app, Jason.encode!(message)}, name: :dead_letter_client)
  rescue
    e -> Logger.error("Unable to dead-letter message: #{inspect(message)}\n\treason: #{inspect(e)}")
  end

  defp endpoint do
    Application.get_env(:yeet, :endpoint)
  end

  defp topic do
    Application.get_env(:yeet, :topic)
  end
end

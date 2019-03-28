defmodule Yeet.KafkaHelper do
  @moduledoc fals
  def produce(message) do
    :brod.start_client(endpoint(), :client_1, [])
    :brod.start_producer(:client_1, topic(), [])
    :brod.produce_sync(:client_1, topic(), 0, "key", Jason.encode!(message))
  end

  defp endpoint do
    Application.get_env(:yeet, :endpoint)
  end

  defp topic do
    Application.get_env(:yeet, :topic)
  end
end

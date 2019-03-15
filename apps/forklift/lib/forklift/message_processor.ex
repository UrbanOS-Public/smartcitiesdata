defmodule Forklift.MessageProcessor do
  @moduledoc false
  require Logger
  alias Forklift.{MessageAccumulator, DatasetRegistryServer, CacheClient, DeadLetterQueue}
  alias SCOS.{RegistryMessage, DataMessage}

  @data_topic Application.get_env(:forklift, :data_topic)
  @registry_topic Application.get_env(:forklift, :registry_topic)

  def handle_messages(messages) do
    Enum.each(messages, &process_message/1)
  end

  defp process_message(%{topic: topic, value: value, offset: offset}) do
    case topic do
      @data_topic -> process_data_message(value, offset)
      @registry_topic -> process_registry_message(value)
      _ -> Logger.error("Unknown topic #{topic} with message #{value}")
    end
  end

  defp process_data_message(raw_message, offset) do
    case DataMessage.new(raw_message) do
    {:ok, message} -> CacheClient.write(raw_message, message.dataset_id, offset)
    {:error, reason} ->
      DeadLetterQueue.enqueue(raw_message)
      Logger.warn("Failed to parse message: #{reason} : #{raw_message}")
    end
  end
  
  def process_registry_message(value) do
    with {:ok, registry_message} <- RegistryMessage.new(value) do
      DatasetRegistryServer.send_message(registry_message)
    else
      {:error, reason} -> Logger.error("Unable to process message: #{value} : #{inspect(reason)}")
    end
  end
end

defmodule Forklift.MessageProcessor do
  @moduledoc false
  use SmartCity.Registry.MessageHandler
  require Logger
  alias Forklift.{DatasetRegistryServer, CacheClient, DeadLetterQueue}

  def handle_messages(messages) do
    Enum.each(messages, &process_data_message/1)
  end

  defp process_data_message(%{value: raw_message, offset: offset}) do
    case SmartCity.Data.new(raw_message) do
      {:ok, message} ->
        CacheClient.write(raw_message, message.dataset_id, offset)

      {:error, reason} ->
        DeadLetterQueue.enqueue(raw_message)
        Logger.warn("Failed to parse message: #{inspect(reason)} : #{raw_message}")
    end
  end

  def handle_dataset(dataset) do
    DatasetRegistryServer.send_message(dataset)
  end
end

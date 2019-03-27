defmodule Forklift.MessageProcessor do
  @moduledoc false
  use SmartCity.Registry.MessageHandler
  require Logger
  alias Forklift.{DatasetRegistryServer, DataBuffer, DeadLetterQueue}

  def handle_messages(messages) do
    Enum.each(messages, &process_data_message/1)
  end

  defp process_data_message(%{value: raw_message}) do
    case SmartCity.Data.new(raw_message) do
      {:ok, data} ->
        DataBuffer.write(data)

      {:error, reason} ->
        DeadLetterQueue.enqueue(raw_message)
        Logger.warn("Failed to parse message: #{inspect(reason)} : #{raw_message}")
    end
  end

  def handle_dataset(dataset) do
    DatasetRegistryServer.send_message(dataset)
  end
end

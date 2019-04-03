defmodule Forklift.MessageProcessor do
  @moduledoc false
  use SmartCity.Registry.MessageHandler
  require Logger
  alias Forklift.{DatasetRegistryServer, DataBuffer, DeadLetterQueue}

  def handle_message(message) do
    process_data_message(message)
  end

  defp process_data_message(%{value: raw_message}) do
    case SmartCity.Data.new(raw_message) do
      {:ok, data} ->
        case DataBuffer.write(data) do
          {:ok, _} -> :ok
          {:error, _} -> :error
        end

      {:error, reason} ->
        Logger.warn("Failed to parse message: #{inspect(reason)} : #{raw_message}")
        DeadLetterQueue.enqueue(raw_message)
    end
  end

  def handle_dataset(dataset) do
    DatasetRegistryServer.send_message(dataset)
  end
end

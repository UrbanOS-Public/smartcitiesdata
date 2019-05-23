defmodule Forklift.Messages.MessageProcessor do
  @moduledoc """
  Reads data off kafka topics, buffering it in batches.
  """
  require Logger
  alias Forklift.Messages.DataBuffer
  alias Forklift.DeadLetterQueue

  @doc """
  Handle each kafka message.
  """
  def handle_message(message) do
    process_data_message(message)
  end

  defp process_data_message(%{key: key, value: raw_message}) do
    case SmartCity.Data.new(raw_message) do
      {:ok, data} ->
        new_oper =
          data
          |> Map.get(:operational)
          |> Map.put("forklift_start_time", SmartCity.Data.Timing.current_time())
          |> Map.put("kafka_key", key)

        data = Map.put(data, :operational, new_oper)

        case DataBuffer.write(data) do
          {:ok, _} -> :ok
          {:error, _} -> :error
        end

      {:error, reason} ->
        Logger.warn("Failed to parse message: #{inspect(reason)} : #{raw_message}")
        DeadLetterQueue.enqueue(raw_message)
    end
  end
end

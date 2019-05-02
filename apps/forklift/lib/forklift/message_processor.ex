defmodule Forklift.MessageProcessor do
  @moduledoc false
  use SmartCity.Registry.MessageHandler
  require Logger
  alias Forklift.{DataBuffer, DeadLetterQueue}

  def handle_message(message) do
    process_data_message(message)
  end

  defp process_data_message(%{value: raw_message}) do
    case SmartCity.Data.new(raw_message) do
      {:ok, data} ->
        new_oper =
          data
          |> Map.get(:operational)
          |> Map.put("forklift_start_time", SmartCity.Data.Timing.current_time())

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

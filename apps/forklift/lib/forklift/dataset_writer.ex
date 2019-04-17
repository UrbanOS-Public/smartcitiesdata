defmodule Forklift.DatasetWriter do
  @moduledoc false

  alias Forklift.{DataBuffer, PersistenceClient, RetryTracker, DeadLetterQueue}

  def perform(dataset_id) do
    pending = DataBuffer.get_pending_data(dataset_id)

    case upload_pending_data(dataset_id, pending) do
      :continue ->
        unread = DataBuffer.get_unread_data(dataset_id)
        upload_unread_data(dataset_id, unread)
        :ok

      :retry ->
        :ok
    end
  end

  defp upload_unread_data(_dataset_id, []), do: nil

  defp upload_unread_data(dataset_id, data) when length(data) > 0 do
    payloads = extract_payloads(data)

    if PersistenceClient.upload_data(dataset_id, payloads) == :ok do
      DataBuffer.mark_complete(dataset_id, data)
      DataBuffer.cleanup_dataset(dataset_id, data)
    end
  end

  defp upload_pending_data(_dataset_id, []), do: :continue

  defp upload_pending_data(dataset_id, data) do
    payloads = extract_payloads(data)

    case PersistenceClient.upload_data(dataset_id, payloads) do
      :ok ->
        cleanup_pending(dataset_id, data)
        :continue

      {:error, _} ->
        if RetryTracker.get_and_increment_retries(dataset_id) > 3 do
          Enum.each(data, fn message -> DeadLetterQueue.enqueue(message) end)
          cleanup_pending(dataset_id, data)

          :continue
        else
          :retry
        end
    end
  end

  defp extract_payloads(data) do
    Enum.map(data, fn %{data: d} -> d.payload end)
  end

  defp cleanup_pending(dataset_id, data) do
    DataBuffer.mark_complete(dataset_id, data)
    DataBuffer.cleanup_dataset(dataset_id, data)
    RetryTracker.reset_retries(dataset_id)
  end
end

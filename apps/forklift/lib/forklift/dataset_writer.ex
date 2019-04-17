defmodule Forklift.DatasetWriter do
  @moduledoc false

  alias Forklift.{DataBuffer, PersistenceClient, RetryTracker, DeadLetterQueue}

  def perform(dataset_id) do
    {pending, unread} = DataBuffer.get_pending_data(dataset_id)
    upload_pending_data(dataset_id, pending)
    upload_unread_data(dataset_id, unread)
  end

  def upload_unread_data(dataset_id, []), do: nil

  def upload_unread_data(dataset_id, data) when length(data) > 0 do
    payloads = extract_payloads(data)

    if PersistenceClient.upload_data(dataset_id, payloads) == :ok do
      DataBuffer.mark_complete(dataset_id, data)
      DataBuffer.cleanup_dataset(dataset_id, data)
    end
  end

  def upload_pending_data(dataset_id, []), do: nil

  def upload_pending_data(dataset_id, data) do
    payloads = extract_payloads(data)

    if PersistenceClient.upload_data(dataset_id, payloads) == :ok do
      cleanup_pending(dataset_id, data)
    else
      RetryTracker.mark_retry(dataset_id)

      if RetryTracker.get_retries(dataset_id) > 3 do
        Enum.each(data, fn message -> DeadLetterQueue.enqueue(message) end)
        cleanup_pending(dataset_id, data)
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

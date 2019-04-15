defmodule Forklift.DatasetWriter do
  @moduledoc false

  alias Forklift.{DataBuffer, PersistenceClient, RetryTracker, DeadLetterQueue}

  def perform(dataset_id) do
    {pending, unread} = DataBuffer.get_pending_data(dataset_id)
    IO.inspect("PENDING (#{dataset_id}): #{inspect(pending)}")
    IO.inspect("UNREAD (#{dataset_id}): #{inspect(unread)}")

    upload_pending_data(dataset_id, pending)
    upload_unread_data(dataset_id, unread)
  end

  def upload_unread_data(dataset_id, data) when length(data) > 0 do
    payloads = Enum.map(data, fn %{data: d} -> d.payload end)

    IO.inspect("!!!!!!!!!!")
    IO.inspect(payloads)

    if PersistenceClient.upload_data(dataset_id, payloads) == :ok do
      IO.inspect("THE BAD THING HAPPENED")
      DataBuffer.mark_complete(dataset_id, data)
      DataBuffer.cleanup_dataset(dataset_id, data)
    end
  end

  def upload_unread_data(dataset_id, data), do: :ok

  def upload_pending_data(dataset_id, data) when length(data) > 0 do
    IO.puts("HIT PENDING!!!!!!!!!!!")
    payloads = Enum.map(data, fn %{data: d} -> d.payload end)

    if PersistenceClient.upload_data(dataset_id, payloads) == :ok do
      cleanup_pending(dataset_id, data)
    else
      IO.puts("HIT PENDING ELSE BLOCK")
      RetryTracker.mark_retry(dataset_id)

      IO.puts("Retries (#{dataset_id}): #{inspect(RetryTracker.get_retries(dataset_id))}")

      if RetryTracker.get_retries(dataset_id) > 3 do
        Enum.each(data, fn message -> DeadLetterQueue.enqueue(message) end)
        cleanup_pending(dataset_id, data)
      end
    end
  end

  def upload_pending_data(dataset_id, data), do: IO.puts("HIT THE PENDING CATCH ALL!!!!!!!!!!!")

  def cleanup_pending(dataset_id, data) do
    DataBuffer.mark_complete(dataset_id, data)
    DataBuffer.cleanup_dataset(dataset_id, data)
    RetryTracker.reset_retries(dataset_id)
  end
end

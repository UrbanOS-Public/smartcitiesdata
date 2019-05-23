defmodule Forklift.Messages.DataBuffer do
  @moduledoc """
  Module for managing buffers (streams) of data messages.
  """
  require Logger

  @number_of_empty_reads_to_delete Application.get_env(:forklift, :number_of_empty_reads_to_delete, 50)

  alias SmartCity.Data
  alias Forklift.Messages.{RedisStreamsClient, EmptyStreamTracker}

  def write(%Data{} = data) do
    RedisStreamsClient.write(data)
  end

  def get_pending_datasets() do
    RedisStreamsClient.get_pending_datasets()
  end

  def get_pending_data(dataset_id) do
    RedisStreamsClient.xread_group_pending(dataset_id)
  end

  def get_unread_data(dataset_id) do
    RedisStreamsClient.xread_group_new(dataset_id)
  end

  def mark_complete(dataset_id, messages) when is_list(messages) do
    RedisStreamsClient.mark_complete(dataset_id, messages)
  end

  @doc """
  Deletes the buffer for a dataset when no messages have been read for awhile (per the `number_of_empty_reads_to_delete` module attribute)
  """
  def cleanup_dataset(dataset_id) do
    number = EmptyStreamTracker.get_and_increment_empty_reads(dataset_id)

    if number >= @number_of_empty_reads_to_delete do
      RedisStreamsClient.delete_inactive_stream(dataset_id)
    end
  end

  def reset_empty_reads(dataset_id) do
    EmptyStreamTracker.reset_empty_reads(dataset_id)
  end
end

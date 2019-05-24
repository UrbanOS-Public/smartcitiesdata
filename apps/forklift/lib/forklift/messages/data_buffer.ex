defmodule Forklift.Messages.DataBuffer do
  @moduledoc """
  Module for managing buffers (streams) of data messages.
  """
  alias SmartCity.Data
  alias Forklift.Messages.EmptyStreamTracker
  require Logger

  @redis Forklift.Application.redis_client()
  @consumer_group "forklift"
  @consumer "consumer1"
  @key_prefix "forklift:data:"
  @batch_size Application.get_env(:forklift, :cache_processing_batch_size)
  @number_of_empty_reads_to_delete Application.get_env(:forklift, :number_of_empty_reads_to_delete, 50)

  @doc """
  Write a dataset to a stream (buffer)
  """
  def write(%Data{dataset_id: dataset_id} = data) do
    with {:json, {:ok, json}} <- {:json, Jason.encode(data)},
         {:redis, {:ok, result}} <- {:redis, xadd(dataset_id, json)} do
      {:ok, result}
    else
      {:json, {:error, reason}} ->
        Logger.warn(fn -> "Failed to encode data message: REASON: #{inspect(reason)} -- Data: #{inspect(data)}" end)
        {:error, reason}

      {:redis, {:error, reason}} ->
        Logger.warn(fn -> "Failed to write to redis: REASON - #{inspect(reason)} -- Data: #{inspect(data)}" end)
        {:error, reason}
    end
  end

  @doc """
  Get dataset_id's of all streams with pending messages.
  Messages are considered pending if they have been previously read by forklift but not yet inserted into presto
  """
  def get_pending_datasets() do
    case @redis.command(["KEYS", stream_key("*")]) do
      {:ok, result} ->
        Enum.map(result, &extract_dataset_id/1)

      {:error, reason} ->
        Logger.warn(fn -> "Error when talking to redis : REASON - #{inspect(reason)}" end)
        []
    end
  end

  @doc """
  Read all pending (unacknowledged) messages in a stream for a given dataset
  """
  def get_pending_data(dataset_id) do
    xread_group(dataset_id, "0")
  end

  @doc """
  Read all new messages in a stream for a given dataset
  """
  def get_unread_data(dataset_id) do
    xread_group(dataset_id, ">")
  end

  @doc """
  Acknowledge a dataset's messages as written to presto so that they can be removed from the stream.
  """
  def mark_complete(dataset_id, messages) do
    key = stream_key(dataset_id)
    message_keys = Enum.map(messages, fn message -> message.key end)

    ack_command = ["XACK", key, @consumer_group | message_keys]
    del_command = ["XDEL", key | message_keys]

    case @redis.pipeline([ack_command, del_command]) do
      {:ok, _result} -> :ok
      result -> result
    end
  end

  @doc """
  Deletes the buffer for a dataset when no messages have been read for awhile (per the `number_of_empty_reads_to_delete` module attribute)
  """
  def cleanup_dataset(dataset_id) do
    number = EmptyStreamTracker.get_and_increment_empty_reads(dataset_id)

    if number >= @number_of_empty_reads_to_delete do
      delete_inactive_stream(dataset_id)
    end
  end

  def reset_empty_reads(dataset_id) do
    EmptyStreamTracker.reset_empty_reads(dataset_id)
  end

  defp delete_inactive_stream(dataset_id) do
    case @redis.command!(["XLEN", stream_key(dataset_id)]) do
      0 ->
        Logger.info(fn -> "Deleting stream for dataset #{dataset_id} due to inactivity" end)
        @redis.command!(["DEL", stream_key(dataset_id)])
        EmptyStreamTracker.delete_stream_ref(dataset_id)

      _ ->
        Logger.info("Dataset #{dataset_id} received new data while attempting to delete redis stream")
    end
  end

  defp xread_group(dataset_id, id) do
    key = create_consumer_group(dataset_id)
    command = ["XREADGROUP", "GROUP", @consumer_group, @consumer, "COUNT", @batch_size, "STREAMS", key, id]

    case @redis.command(command) do
      {:ok, response} ->
        response
        |> parse_xread_response()
        |> Map.get(key, [])

      {:error, reason} ->
        Logger.warn(fn -> "Error when talking to redis: REASON - #{inspect(reason)}" end)
        []
    end
  end

  defp create_consumer_group(dataset_id) do
    key = stream_key(dataset_id)
    @redis.command(["XGROUP", "CREATE", key, @consumer_group, "0"])

    key
  end

  defp parse_xread_response(nil), do: %{}

  defp parse_xread_response(response) do
    response
    |> Enum.map(fn [dataset_key, entries] -> {dataset_key, parse_xread_entries(dataset_key, entries)} end)
    |> Map.new()
  end

  defp parse_xread_entries(dataset_key, entries) do
    entries
    |> Enum.map(fn [key, ["message", message]] -> %{key: key, data: parse_data_json(dataset_key, key, message)} end)
    |> Enum.filter(fn %{data: data} -> data != nil end)
  end

  defp stream_key(dataset_id), do: "#{@key_prefix}#{dataset_id}"

  defp parse_data_json(dataset_key, key, json) do
    case Data.new(json) do
      {:ok, data} ->
        data

      {:error, reason} ->
        dataset_id = extract_dataset_id(dataset_key)
        Forklift.DeadLetterQueue.enqueue(json)
        mark_complete(dataset_id, [%{key: key}])
        Logger.warn("Failed to parse data message: #{inspect(json)} -- REASON: #{inspect(reason)}")
        nil
    end
  end

  defp extract_dataset_id(key) do
    String.replace_leading(key, @key_prefix, "")
  end

  defp xadd(dataset_id, json) do
    @redis.command(["XADD", stream_key(dataset_id), "*", "message", json])
  end
end

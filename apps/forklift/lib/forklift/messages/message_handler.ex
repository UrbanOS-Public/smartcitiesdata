defmodule Forklift.Messages.MessageHandler do
  @moduledoc """
  Reads data off kafka topics, buffering it in batches.
  """
  use Retry
  alias Forklift.Util
  require Logger

  @doc """
  Handle each kafka message.
  """
  def handle_messages(messages) do
    messages
    |> Enum.map(&parse/1)
    |> Enum.map(&yeet_error/1)
    |> Enum.reject(&error_tuple?/1)
    |> Forklift.handle_batch()
    |> send_to_output_topic()

    :ok
  end

  defp parse(%{key: key, value: value} = message) do
    case SmartCity.Data.new(value) do
      {:ok, datum} -> Util.add_to_metadata(datum, :kafka_key, key)
      {:error, reason} -> {:error, reason, message}
    end
  end

  defp send_to_output_topic(data_messages) do
    data_messages
    |> Enum.map(fn datum -> {datum._metadata.kafka_key, Util.remove_from_metadata(datum, :kafka_key)} end)
    |> Enum.map(fn {key, datum} -> {key, Jason.encode!(datum)} end)
    |> Util.chunk_by_byte_size(max_bytes(), fn {key, value} -> byte_size(key) + byte_size(value) end)
    |> Enum.each(&Kaffe.Producer.produce_sync(output_topic(), &1))
  end

  defp yeet_error({:error, reason, message} = error_tuple) do
    Forklift.DeadLetterQueue.enqueue(message, reason: reason)
    error_tuple
  end

  defp yeet_error(valid), do: valid

  defp error_tuple?({:error, _, _}), do: true
  defp error_tuple?(_), do: false

  defp output_topic() do
    Application.get_env(:forklift, :output_topic)
  end

  defp max_bytes() do
    Application.get_env(:forklift, :max_outgoing_bytes, 900_000)
  end
end

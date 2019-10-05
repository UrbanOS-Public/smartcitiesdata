defmodule Forklift.MessageHandler do
  @moduledoc """
  Reads data off kafka topics, buffering it in batches.
  """
  use Retry
  use Elsa.Consumer.MessageHandler

  alias Forklift.Util
  require Logger

  def init(args \\ []) do
    dataset = Keyword.fetch!(args, :dataset)
    {:ok, %{dataset: dataset}}
  end

  @doc """
  Handle each kafka message.
  """
  def handle_messages(messages, %{dataset: %SmartCity.Dataset{} = dataset}) do
    messages
    |> Enum.map(&parse/1)
    |> Enum.map(&yeet_error/1)
    |> Enum.reject(&error_tuple?/1)
    |> Forklift.DataWriter.write(dataset: dataset)

    {:ack, %{dataset: dataset}}
  end

  defp parse(%{key: key, value: value} = message) do
    case SmartCity.Data.new(value) do
      {:ok, datum} -> Util.add_to_metadata(datum, :kafka_key, key)
      {:error, reason} -> {:error, reason, message}
    end
  end

  defp yeet_error({:error, reason, message} = error_tuple) do
    Forklift.DeadLetterQueue.enqueue(message, reason: reason)
    error_tuple
  end

  defp yeet_error(valid), do: valid

  defp error_tuple?({:error, _, _}), do: true
  defp error_tuple?(_), do: false
end

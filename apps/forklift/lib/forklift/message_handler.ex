defmodule Forklift.MessageHandler do
  @moduledoc """
  Reads data off kafka topics, buffering it in batches.
  """
  use Retry
  require Logger
  use Elsa.Consumer.MessageHandler

  import SmartCity.Data, only: [end_of_data: 0]
  import SmartCity.Event, only: [data_ingest_end: 0, data_write_complete: 0]
  alias SmartCity.DataWriteComplete
  import Forklift
  alias Forklift.Util

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

    {:ok, event} = DataWriteComplete.new(%{id: dataset.id, timestamp: DateTime.utc_now()})
    Brook.Event.send(instance_name(), data_write_complete(), :forklift, event)

    {:ack, %{dataset: dataset}}
  end

  defp parse(end_of_data() = message), do: message

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

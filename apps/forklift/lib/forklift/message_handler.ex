defmodule Forklift.MessageHandler do
  @moduledoc """
  Reads data off kafka topics, buffering it in batches.
  """
  use Retry
  require Logger
  use Elsa.Consumer.MessageHandler

  import SmartCity.Data, only: [end_of_data: 0]
  import SmartCity.Event, only: [data_write_complete: 0, event_log_published: 0]
  alias SmartCity.DataWriteComplete
  alias Forklift.Util

  @instance_name Forklift.instance_name()

  def init(args \\ []) do
    dataset = Keyword.fetch!(args, :dataset)
    {:ok, %{dataset: dataset}}
  end

  @doc """
  Handle each kafka message.
  """
  def handle_messages(messages, %{dataset: %SmartCity.Dataset{} = dataset}) do
    IO.inspect(length(messages), label: "count of messages")

    timed_messages =
      messages
      |> Enum.map(&parse/1)
      |> Enum.map(&yeet_error/1)
      |> Enum.reject(&error_tuple?/1)
      |> group_by_each_extraction()
      |> Enum.map(fn {%{ingestion_id: i, extraction_start_time: e}, msgs} ->
        Forklift.DataWriter.write(msgs, dataset: dataset, ingestion_id: i, extraction_start_time: e)
      end)
      |> List.flatten()

    Task.start(fn ->
      result = Forklift.DataWriter.write_to_topic(timed_messages)

      Logger.debug(fn ->
        "Finished writing #{Enum.count(timed_messages)} timed messages for dataset #{dataset.id} with result #{
          inspect(result)
        }"
      end)
    end)

    {:ok, event} = DataWriteComplete.new(%{id: dataset.id, timestamp: DateTime.utc_now()})
    Brook.Event.send(@instance_name, data_write_complete(), :forklift, event)

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

  defp group_by_each_extraction(msgs) do
    msgs
    |> Enum.group_by(fn msg ->
      i = Map.get(msg, :ingestion_id)
      e = Map.get(msg, :extraction_start_time)
      unix_e = e |> Timex.parse!("{ISO:Extended:Z}") |> Timex.to_unix()
      %{:ingestion_id => i, :extraction_start_time => unix_e}
    end)
  end
end

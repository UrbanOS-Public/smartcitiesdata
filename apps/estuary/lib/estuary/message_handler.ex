defmodule Estuary.MessageHandler do
  @moduledoc """
  Estuary.MessageHandler reads an event from the event stream and persists it.
  """
  alias Estuary.EventTable
  use Elsa.Consumer.MessageHandler
  require Logger

  def handle_messages(messages) do
    Enum.each(messages, fn message -> process_message(message) end)

    Logger.debug("Messages #{inspect(messages)} were sent to the event stream")
    :ack
  end

  defp process_message(message) do
    case Jason.decode(message.value) do
      {:ok, %{"author" => _, "create_ts" => _, "data" => _, "type" => _} = event} ->
        do_insert(message, event)

      {_, term} ->
        process_error(message, term)
    end
  end

  defp do_insert(_message, event) do
    case EventTable.insert_event_to_table(event) do
      {:error, message} ->
        process_error(message, event)

      term ->
        term
    end
  end

  defp process_error(message, data) do
    DeadLetter.process("", message, "estuary",
      reason: "could not process because #{inspect(data)}"
    )
  end

  # SC - Starts
  alias Estuary.Util
  import Estuary
  # import SmartCity.Data, only: [end_of_data: 0]

  @reader Application.get_env(:estuary, :topic_reader)

  def handle_messages(messages) do
    messages
    |> Enum.map(&parse_message_value/1)
    |> Enum.map(&yeet_error/1)

    # messages
    # |> Enum.map(&parse/1)
    # |> Enum.map(&yeet_error/1)
    # |> Enum.reject(&error_tuple?/1)
    # |> Estuary.DataWriter.write_to_table(dataset: dataset)

    # {:ack, %{dataset: dataset}}

    # Logger.debug("Messages #{inspect(messages)} were sent to the eventstream")
    # :ack
  end

  defp parse_message_value(message) do
    message.value
    |> Jason.decode()
    |> process_message()
  end

  defp process_message(
         {:ok, %{"author" => _, "create_ts" => _, "data" => _, "type" => _} = event}
       ) do
    # init_args <- reader_args(event)
    reader_args(event)
    # :ok = @reader.init(init_args)

    event
    |> DatasetSchema.parse_event_args()
    |> DataWriter.write()
  end

  defp process_message({_, term}) do
    :discard
  end

  # defp parse(end_of_data() = message), do: message

  defp parse(%{key: key, value: value} = message) do
    case SmartCity.Data.new(value) do
      {:ok, datum} -> Util.add_to_metadata(datum, :kafka_key, key)
      {:error, reason} -> {:error, reason, message}
    end
  end

  defp yeet_error({:error, reason, message} = error_tuple) do
    Estuary.DeadLetterQueue.enqueue(message, reason: reason)
    error_tuple
  end

  defp yeet_error(valid), do: valid

  defp error_tuple?({:error, _, _}), do: true
  defp error_tuple?(_), do: false

  defp reader_args(event) do
    [
      instance: instance_name(),
      connection: Application.get_env(:estuary, :connection),
      endpoints: Application.get_env(:estuary, :elsa_brokers),
      topic: Application.get_env(:estuary, :event_stream_topic),
      handler: Estuary.MessageHandler
      # handler_init_args: ,#[dataset: event],
      # topic_subscriber_config: ,#Application.get_env(:estuary, :topic_subscriber_config, []),
      # retry_count: ,#Application.get_env(:estuary, :retry_count),
      # retry_delay: #Application.get_env(:estuary, :retry_initial_delay)
    ]
  end

  # SC - Ends 
end

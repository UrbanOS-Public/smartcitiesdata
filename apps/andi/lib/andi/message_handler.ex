defmodule Andi.MessageHandler do
  @moduledoc false

  use Elsa.Consumer.MessageHandler
  require Logger

  alias Andi.InputSchemas.Datasets

  def init(_) do
    {:ok, %{}}
  end

  def handle_messages(messages, state) do
    Enum.each(messages, &handle_message(&1, state))

    {:ack, state}
  end

  def handle_message(%Elsa.Message{timestamp: timestamp, value: value}, state) do
    {ok, timestamp_datetime} =
      timestamp
      |> DateTime.from_unix!()
      |> DateTime.shift_zone("Etc/UTC")

    dlq_message =
      value
      |> Jason.decode!(value)
      |> Map.put("timestamp", DateTime.to_iso8601(timestamp_datetime))

    Datasets.update_latest_dlq_message(dlq_message)

    {:ack, state}
  end

  def handle_message(%Elsa.Message{value: value}, state) do
    current_time = DateTime.utc_now() |> DateTime.to_iso8601()

    dlq_message =
      value
      |> Jason.decode!(value)
      |> Map.put("timestamp", current_time)

    Datasets.update_latest_dlq_message(dlq_message)

    {:ack, state}
  end

  def handle_message(message, state) do
    Logger.warn("Could not process DLQ message #{message}")

    {:ack, state}
  end
end
